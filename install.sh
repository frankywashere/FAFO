#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=========================================="
echo "Installing AIControl CLI for Claude Code"
echo "=========================================="

# Build Swift CLI
echo ""
echo "[1/4] Building Swift CLI tool..."
swift build -c release --product AIControlCLI

# Install binary
echo ""
echo "[2/4] Installing aicontrol to /usr/local/bin..."
sudo cp .build/release/AIControlCLI /usr/local/bin/aicontrol
sudo chmod +x /usr/local/bin/aicontrol

# Install Claude Code skill
echo ""
echo "[3/4] Installing Claude Code skill..."
SKILL_SRC="$SCRIPT_DIR/.claude/skills/FAFO"
SKILL_DEST="$HOME/.claude/skills/FAFO"

mkdir -p "$SKILL_DEST"

if [ -f "$SKILL_SRC/SKILL.md" ]; then
    cp "$SKILL_SRC/SKILL.md" "$SKILL_DEST/SKILL.md"
    echo "  Installed SKILL.md"
else
    echo "  Warning: SKILL.md not found at $SKILL_SRC/SKILL.md"
fi

if [ -d "$SKILL_SRC/examples" ] && [ "$(ls -A "$SKILL_SRC/examples" 2>/dev/null)" ]; then
    mkdir -p "$SKILL_DEST/examples"
    cp -r "$SKILL_SRC/examples/"* "$SKILL_DEST/examples/"
    echo "  Installed examples/"
fi

# Verify installation
echo ""
echo "[4/4] Verifying installation..."
aicontrol --version

echo ""
echo "=========================================="
echo "Installation complete!"
echo "=========================================="
echo ""
echo "Installed:"
echo "  - aicontrol CLI: /usr/local/bin/aicontrol"
echo "  - Claude Code skill: ~/.claude/skills/FAFO/"
echo ""
echo "Usage: aicontrol <command>"
echo ""
echo "Available commands:"
echo "  capture      - Capture screenshot"
echo "  click        - Click at coordinates"
echo "  type         - Type text"
echo "  key          - Press key/combo"
echo "  calibrate    - Test accuracy"
echo "  status       - Check permissions"
echo ""
echo "Run 'aicontrol --help' for full command list"
echo ""
echo "IMPORTANT: Ensure these permissions are granted:"
echo "  1. Screen Recording: System Settings → Privacy → Screen Recording"
echo "  2. Accessibility: System Settings → Privacy → Accessibility"
echo ""
