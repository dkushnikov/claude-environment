#!/bin/bash
# Claude Environment — server setup
# Run this AFTER install.sh on a background/server machine.
# Creates log directory, deploy key, data symlinks, and loads LaunchAgents.
#
# Usage: ./server-setup.sh
# Prerequisites: install.sh already run, git configured

set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"
LOG_DIR="/var/log/claude"
LAUNCHD_DIR="$DOTFILES_DIR/launchd"
LAUNCHD_TARGET="$HOME/Library/LaunchAgents"

echo "Claude Environment — Server Setup"
echo "==================================="
echo ""
echo "Dotfiles: $DOTFILES_DIR"
echo "Log dir:  $LOG_DIR"
echo ""

# --- 1. Log directory ---
echo "1. Log directory"
if [ -d "$LOG_DIR" ]; then
    echo "   ok  $LOG_DIR exists"
else
    echo "   Creating $LOG_DIR..."
    sudo mkdir -p "$LOG_DIR" && sudo chown "$USER" "$LOG_DIR" && \
        echo "   ok  $LOG_DIR created" || \
        { echo "   !!  Failed. Run: sudo mkdir -p $LOG_DIR && sudo chown $USER $LOG_DIR"; exit 1; }
fi
echo ""

# --- 2. Deploy key (for git pull without agent forwarding) ---
echo "2. Deploy key"
DEPLOY_KEY="$HOME/.ssh/claude-deploy"
if [ -f "$DEPLOY_KEY" ]; then
    echo "   ok  $DEPLOY_KEY exists"
else
    echo "   Generating deploy key..."
    ssh-keygen -t ed25519 -f "$DEPLOY_KEY" -N "" -C "claude-deploy@$(hostname)" && \
        echo "   ok  Key generated. Add public key to GitHub:" && \
        echo "   ---" && \
        cat "${DEPLOY_KEY}.pub" && \
        echo "   ---" && \
        echo "   GitHub → repo Settings → Deploy keys → Add" || \
        echo "   !!  Key generation failed"
fi
echo ""

# --- 3. LaunchAgents ---
echo "3. LaunchAgents"
mkdir -p "$LAUNCHD_TARGET"

if [ -d "$LAUNCHD_DIR" ]; then
    for plist in "$LAUNCHD_DIR"/*.plist; do
        [ -f "$plist" ] || continue
        name=$(basename "$plist")
        label=$(basename "$name" .plist)
        target="$LAUNCHD_TARGET/$name"

        # Copy (not symlink — launchd prefers real files in ~/Library/LaunchAgents)
        if [ -f "$target" ]; then
            if diff -q "$plist" "$target" >/dev/null 2>&1; then
                echo "   ok  $name (unchanged)"
            else
                cp "$plist" "$target"
                echo "   upd $name (updated)"
                launchctl unload "$target" 2>/dev/null || true
                launchctl load "$target"
                echo "        reloaded"
            fi
        else
            cp "$plist" "$target"
            launchctl load "$target"
            echo "   new $name (loaded)"
        fi
    done
else
    echo "   skip  No launchd/ directory found"
fi
echo ""

# --- 4. Data symlinks (optional) ---
echo "4. Data symlinks"
echo "   Configure data symlinks for your pipelines:"
echo "   Example:"
echo "     ln -s ~/Library/Mobile\\ Documents/.../Calendar ~/Obsidian/YourVault/_inputs/Calendar"
echo "     ln -s ~/Library/Mobile\\ Documents/.../Plaud    ~/Obsidian/YourVault/_inputs/Plaud"
echo "   Adjust paths to your iCloud Drive / Dropbox layout."
echo ""

# --- 5. Verify ---
echo "5. Verification"
echo "   Running check.sh..."
echo ""
"$DOTFILES_DIR/check.sh"

echo ""
echo "==================================="
echo "Server setup complete."
echo ""
echo "Next steps:"
echo "  1. Add deploy key to GitHub (if generated above)"
echo "  2. Set up data symlinks for your pipelines"
echo "  3. Authenticate services: gws auth login, gh auth login, etc."
echo "  4. Wait for first cron cycle (check logs in $LOG_DIR)"
echo "  5. Monitor: tail -f $LOG_DIR/*.log"
