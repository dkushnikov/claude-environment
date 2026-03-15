#!/bin/bash
# Claude Environment — install script
# Creates symlinks from dotfiles to ~/.claude/
# Idempotent: safe to run multiple times.
#
# Usage: ./install.sh

set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"
CLAUDE_DIR="$HOME/.claude"

echo "Claude Environment Setup"
echo "========================"
echo ""
echo "Dotfiles: $DOTFILES_DIR"
echo "Target:   $CLAUDE_DIR"
echo ""

# Ensure ~/.claude exists
mkdir -p "$CLAUDE_DIR"

# Symlink dotfiles into ~/.claude/
symlink() {
    local source="$1"
    local target="$2"
    local name="$(basename "$target")"

    if [ -L "$target" ]; then
        current=$(readlink "$target")
        if [ "$current" = "$source" ]; then
            echo "  ok  $name → $source"
            return
        fi
        echo "  fix $name (was → $current)"
        rm "$target"
    elif [ -e "$target" ]; then
        echo "  bak $name exists, backing up to $target.bak"
        mv "$target" "$target.bak"
    fi

    ln -s "$source" "$target"
    echo "  new $name → $source"
}

echo "Symlinks:"

# Only symlink files that exist
[ -f "$DOTFILES_DIR/dotfiles/CLAUDE.md" ] && \
    symlink "$DOTFILES_DIR/dotfiles/CLAUDE.md" "$CLAUDE_DIR/CLAUDE.md"
[ -f "$DOTFILES_DIR/dotfiles/settings.json" ] && \
    symlink "$DOTFILES_DIR/dotfiles/settings.json" "$CLAUDE_DIR/settings.json"
[ -d "$DOTFILES_DIR/dotfiles/rules" ] && \
    symlink "$DOTFILES_DIR/dotfiles/rules" "$CLAUDE_DIR/rules"
[ -d "$DOTFILES_DIR/dotfiles/skills" ] && \
    symlink "$DOTFILES_DIR/dotfiles/skills" "$CLAUDE_DIR/skills"

# Machine-specific environment
echo ""
echo "Environment:"
ENV_FILE="$DOTFILES_DIR/dotfiles/rules/environment.md"
if [ -f "$ENV_FILE" ]; then
    echo "  ok  rules/environment.md exists"
else
    EXAMPLE="$DOTFILES_DIR/dotfiles/rules/environment.md.example"
    if [ -f "$EXAMPLE" ]; then
        cp "$EXAMPLE" "$ENV_FILE"
        echo "  new rules/environment.md created from template — edit it!"
    else
        echo "  !!  rules/environment.md.example not found"
    fi
fi

# Log directory (for jobs)
echo ""
echo "Log directory:"
LOG_DIR="/var/log/claude"
if [ -d "$LOG_DIR" ]; then
    echo "  ok  $LOG_DIR exists"
else
    echo "  Creating $LOG_DIR (may require sudo)..."
    sudo mkdir -p "$LOG_DIR" 2>/dev/null && sudo chown "$USER" "$LOG_DIR" && \
        echo "  ok  $LOG_DIR created" || \
        echo "  !!  Failed to create $LOG_DIR (create manually: sudo mkdir -p $LOG_DIR && sudo chown $USER $LOG_DIR)"
fi

echo ""
echo "========================"
echo "Done. Next steps:"
echo "  1. Edit dotfiles/rules/environment.md (set your machine name and role)"
echo "  2. Copy dotfiles/CLAUDE.md.example → dotfiles/CLAUDE.md and customize"
echo "  3. Copy dotfiles/settings.json.example → dotfiles/settings.json and customize"
echo "  4. Run ./check.sh to validate"
echo "  5. Set up pipelines you need (see pipelines/)"
