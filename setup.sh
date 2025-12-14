#!/bin/bash
#
# Setup script for NEO
# Creates symlinks from this repo to ~/.claude/
#

set -e

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
CLAUDE_DIR="$HOME/.claude"

echo "Setting up NEO..."
echo "Repo: $REPO_DIR"
echo "Claude: $CLAUDE_DIR"
echo ""

# Ensure ~/.claude exists
mkdir -p "$CLAUDE_DIR"

# Create symlinks
create_symlink() {
    local src="$1"
    local dest="$2"

    if [ -L "$dest" ]; then
        echo "Updating symlink: $dest"
        rm "$dest"
    elif [ -e "$dest" ]; then
        echo "Backing up existing: $dest → ${dest}.backup"
        mv "$dest" "${dest}.backup"
    fi

    ln -s "$src" "$dest"
    echo "Linked: $dest → $src"
}

create_symlink "$REPO_DIR/agents" "$CLAUDE_DIR/agents"
create_symlink "$REPO_DIR/commands" "$CLAUDE_DIR/commands"
create_symlink "$REPO_DIR/skills" "$CLAUDE_DIR/skills"
create_symlink "$REPO_DIR/settings.json" "$CLAUDE_DIR/settings.json"
create_symlink "$REPO_DIR/.mcp.json" "$CLAUDE_DIR/.mcp.json"

echo ""
echo "NEO setup complete!"
echo ""
echo "Note: Hook scripts in ./hooks/ are referenced by settings.json"
echo "      They don't need to be symlinked separately."
