#!/bin/bash
# permissions-audit.sh — Detect drift in Claude Code permission settings
#
# Claude Code auto-appends one-off commands to the allow list during sessions.
# This script compares current settings against a saved baseline and reports:
# - Rule count drift (+5 = warning, +15 = error)
# - Local rules made redundant by global settings (e.g., Bash(*))
# - Invalid patterns (double slashes, unexpanded variables, >120-char one-offs)
#
# Usage:
#   permissions-audit.sh [project-path]     Show drift report
#   permissions-audit.sh --save-baseline    Save current state as baseline
#
# Integrate into your vault audit or run after major permission cleanups.

set -euo pipefail

GLOBAL_SETTINGS="$HOME/.claude/settings.json"
VAULT_PATH="${1:-.}"
LOCAL_SETTINGS="$VAULT_PATH/.claude/settings.local.json"
BASELINE="$VAULT_PATH/_claude/cache/permissions-baseline.json"

# ── Save baseline mode ──
if [ "${1:-}" = "--save-baseline" ]; then
    VAULT_PATH="${2:-.}"
    LOCAL_SETTINGS="$VAULT_PATH/.claude/settings.local.json"
    BASELINE="$VAULT_PATH/_claude/cache/permissions-baseline.json"
    if [ ! -f "$LOCAL_SETTINGS" ]; then
        echo "❌ No settings.local.json found at $LOCAL_SETTINGS"
        exit 1
    fi
    mkdir -p "$(dirname "$BASELINE")"
    cp "$LOCAL_SETTINGS" "$BASELINE"
    LOCAL_COUNT=$(jq '.permissions.allow | length' "$LOCAL_SETTINGS")
    echo "✅ Baseline saved: $BASELINE ($LOCAL_COUNT rules)"
    exit 0
fi

echo "═══ Permissions Audit ═══"
echo ""

# ── Rule counts ──
GLOBAL_ALLOW=$(jq '.permissions.allow | length' "$GLOBAL_SETTINGS" 2>/dev/null || echo "?")
GLOBAL_DENY=$(jq '.permissions.deny | length' "$GLOBAL_SETTINGS" 2>/dev/null || echo "?")
LOCAL_ALLOW=$(jq '.permissions.allow | length' "$LOCAL_SETTINGS" 2>/dev/null || echo "0")

echo "📊 Counts:"
echo "   Global: $GLOBAL_ALLOW allow, $GLOBAL_DENY deny"
echo "   Local:  $LOCAL_ALLOW allow"

# ── Baseline comparison ──
if [ -f "$BASELINE" ]; then
    BASELINE_COUNT=$(jq '.permissions.allow | length' "$BASELINE")
    DRIFT=$((LOCAL_ALLOW - BASELINE_COUNT))
    BASELINE_DATE=$(stat -f "%Sm" -t "%Y-%m-%d" "$BASELINE" 2>/dev/null || stat -c "%y" "$BASELINE" 2>/dev/null | cut -d' ' -f1)
    echo "   Baseline: $BASELINE_COUNT (saved $BASELINE_DATE)"
    if [ "$DRIFT" -gt 0 ]; then
        ICON="⚠️"
        [ "$DRIFT" -gt 15 ] && ICON="🔴"
        echo "   ${ICON} Drift: +$DRIFT rules since baseline"
    elif [ "$DRIFT" -eq 0 ]; then
        echo "   ✅ No drift"
    else
        echo "   📉 Drift: $DRIFT (fewer rules than baseline)"
    fi
    echo ""

    # Show new rules
    if [ "$DRIFT" -gt 0 ]; then
        echo "📝 New rules (not in baseline):"
        jq -r '.permissions.allow[]' "$LOCAL_SETTINGS" | sort > /tmp/pa_local.txt
        jq -r '.permissions.allow[]' "$BASELINE" | sort > /tmp/pa_baseline.txt
        comm -23 /tmp/pa_local.txt /tmp/pa_baseline.txt | while read -r rule; do
            echo "   + $rule"
        done
        rm -f /tmp/pa_local.txt /tmp/pa_baseline.txt
        echo ""
    fi
else
    echo "   ⚠️  No baseline. Run: permissions-audit.sh --save-baseline $VAULT_PATH"
    echo ""
fi

# ── Duplicate detection (local rules covered by global) ──
DUPES_FOUND=0
DUPES_OUTPUT=""

if [ -f "$LOCAL_SETTINGS" ] && [ -f "$GLOBAL_SETTINGS" ]; then
    HAS_BASH_STAR=$(jq -r '.permissions.allow[]' "$GLOBAL_SETTINGS" | grep -cxF "Bash(*)" || true)
    HAS_WEBFETCH_STAR=$(jq -r '.permissions.allow[]' "$GLOBAL_SETTINGS" | grep -cxF "WebFetch(domain:*)" || true)

    while IFS= read -r rule; do
        # Exact match in global
        if jq -r '.permissions.allow[]' "$GLOBAL_SETTINGS" | grep -qxF "$rule"; then
            DUPES_OUTPUT="${DUPES_OUTPUT}   ⚠️  $rule (exact match in global)\n"
            DUPES_FOUND=$((DUPES_FOUND + 1))
            continue
        fi
        # Bash rules covered by Bash(*)
        if [ "$HAS_BASH_STAR" -gt 0 ] && echo "$rule" | grep -q '^Bash('; then
            DUPES_OUTPUT="${DUPES_OUTPUT}   ⚠️  $rule (covered by global Bash(*))\n"
            DUPES_FOUND=$((DUPES_FOUND + 1))
            continue
        fi
        # WebFetch rules covered by WebFetch(domain:*)
        if [ "$HAS_WEBFETCH_STAR" -gt 0 ] && echo "$rule" | grep -q '^WebFetch('; then
            DUPES_OUTPUT="${DUPES_OUTPUT}   ⚠️  $rule (covered by global WebFetch(domain:*))\n"
            DUPES_FOUND=$((DUPES_FOUND + 1))
            continue
        fi
    done < <(jq -r '.permissions.allow[]' "$LOCAL_SETTINGS" 2>/dev/null)
fi

echo "🔍 Duplicates (local rules covered by global):"
if [ "$DUPES_FOUND" -gt 0 ]; then
    printf "%b" "$DUPES_OUTPUT"
else
    echo "   ✅ None"
fi
echo ""

# ── Invalid patterns ──
INVALID_FOUND=0
INVALID_OUTPUT=""

if [ -f "$LOCAL_SETTINGS" ]; then
    while IFS= read -r rule; do
        # Double slashes
        if echo "$rule" | grep -q '//'; then
            INVALID_OUTPUT="${INVALID_OUTPUT}   ❌ $rule (double slash)\n"
            INVALID_FOUND=$((INVALID_FOUND + 1))
        fi
        # Shell variables
        if echo "$rule" | grep -qE '\$[A-Z_]'; then
            INVALID_OUTPUT="${INVALID_OUTPUT}   ❌ $rule (shell variable — won't expand)\n"
            INVALID_FOUND=$((INVALID_FOUND + 1))
        fi
        # Very long rules (likely one-off commands)
        if [ "${#rule}" -gt 120 ]; then
            INVALID_OUTPUT="${INVALID_OUTPUT}   ⚠️  ${rule:0:80}... (>120 chars — one-off?)\n"
            INVALID_FOUND=$((INVALID_FOUND + 1))
        fi
    done < <(jq -r '.permissions.allow[]' "$LOCAL_SETTINGS" 2>/dev/null)
fi

echo "🔎 Invalid patterns:"
if [ "$INVALID_FOUND" -gt 0 ]; then
    printf "%b" "$INVALID_OUTPUT"
else
    echo "   ✅ None"
fi
echo ""
echo "═══ Done ═══"
