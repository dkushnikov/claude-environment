#!/bin/bash
# Claude Environment — validation script
# Checks that symlinks, config, and pipelines are correctly set up.
# Idempotent, read-only, safe to run anytime.

DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"
CLAUDE_DIR="$HOME/.claude"
errors=0
warnings=0

pass() { echo "  ok  $1"; }
fail() { echo "  ERR $1"; ((errors++)); }
warn() { echo "  !!  $1"; ((warnings++)); }

echo "Claude Environment Check"
echo "========================"

# 1. Symlinks
echo ""
echo "Symlinks:"
for item in CLAUDE.md settings.json rules skills; do
    target="$CLAUDE_DIR/$item"
    if [ -L "$target" ]; then
        pass "$item → $(readlink "$target")"
    elif [ -e "$target" ]; then
        warn "$item exists but is NOT a symlink"
    else
        warn "$item not found (optional — create if needed)"
    fi
done

# 2. Environment
echo ""
echo "Environment:"
env_file="$DOTFILES_DIR/dotfiles/rules/environment.md"
if [ -f "$env_file" ]; then
    if grep -q 'Your Name\|Machine Name\|\[friendly name\]' "$env_file"; then
        warn "environment.md has template placeholders — edit it"
    else
        pass "environment.md configured"
    fi
else
    warn "environment.md not found (run install.sh)"
fi

# 3. Git
echo ""
echo "Git:"
if [ -d "$DOTFILES_DIR/.git" ]; then
    pass "git repo initialized"
    if git -C "$DOTFILES_DIR" remote -v 2>/dev/null | grep -q 'origin'; then
        pass "remote origin configured"
    else
        warn "no remote origin"
    fi
else
    warn "not a git repo"
fi

# 4. Pipeline data (check common symlinks)
echo ""
echo "Pipelines:"
for pipeline in Calendar Voice Health; do
    # Check common vault locations
    for vault_dir in "$HOME/Obsidian/"*/; do
        link="$vault_dir/_inputs/$pipeline"
        if [ -L "$link" ]; then
            pass "$pipeline → $(readlink "$link") ($(basename "$vault_dir"))"
            break
        fi
    done
done

# 5. Jobs
echo ""
echo "Jobs:"
if [ -d "/var/log/claude" ]; then
    pass "log directory /var/log/claude/"
else
    warn "no log directory (create: sudo mkdir -p /var/log/claude && sudo chown $USER /var/log/claude)"
fi

# Check LaunchAgents
for plist in "$DOTFILES_DIR"/jobs/launchd/*.plist; do
    [ -f "$plist" ] || continue
    label="$(basename "${plist%.plist}")"
    installed="$HOME/Library/LaunchAgents/$(basename "$plist")"
    if [ -f "$installed" ]; then
        if launchctl list "$label" >/dev/null 2>&1; then
            pass "$label (loaded)"
        else
            warn "$label installed but not loaded"
        fi
    fi
done

# 6. Gitignore
echo ""
echo "Gitignore:"
if [ -f "$DOTFILES_DIR/.gitignore" ]; then
    if grep -q 'environment.md' "$DOTFILES_DIR/.gitignore"; then
        pass "environment.md gitignored"
    else
        warn "environment.md NOT gitignored (machine-specific!)"
    fi
    if grep -q '\.env' "$DOTFILES_DIR/.gitignore"; then
        pass "*.env gitignored"
    else
        fail "*.env NOT gitignored (secrets!)"
    fi
else
    warn ".gitignore missing"
fi

# Summary
echo ""
echo "========================"
if [ $errors -eq 0 ] && [ $warnings -eq 0 ]; then
    echo "All checks passed."
elif [ $errors -eq 0 ]; then
    echo "$warnings warning(s), 0 errors."
else
    echo "$errors error(s), $warnings warning(s)."
fi
