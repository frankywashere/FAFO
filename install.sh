#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Pre-flight checks
echo ""
echo "[1/5] Checking requirements..."

# Check macOS version (must be 14.0 or higher - Sonoma)
MACOS_VERSION=$(sw_vers -productVersion)
MACOS_MAJOR=$(echo "$MACOS_VERSION" | cut -d. -f1)
if [ "$MACOS_MAJOR" -lt 14 ]; then
    echo ""
    echo "Error: macOS 14 (Sonoma) or newer is required."
    echo "Current version: $MACOS_VERSION"
    echo "Please upgrade your macOS to continue."
    exit 1
fi

# Check for Swift/Xcode Command Line Tools
if ! command -v swift &> /dev/null; then
    echo ""
    echo "Error: Swift is not installed."
    echo ""
    echo "Install Xcode Command Line Tools by running:"
    echo "  xcode-select --install"
    echo ""
    echo "Then run this script again."
    exit 1
fi

# Check Swift version (must be 5.9 or higher)
SWIFT_VERSION_OUTPUT=$(swift --version 2>&1)
SWIFT_VERSION=$(echo "$SWIFT_VERSION_OUTPUT" | grep -oE 'Swift version [0-9]+\.[0-9]+' | grep -oE '[0-9]+\.[0-9]+')
SWIFT_MAJOR=$(echo "$SWIFT_VERSION" | cut -d. -f1)
SWIFT_MINOR=$(echo "$SWIFT_VERSION" | cut -d. -f2)
if [ "$SWIFT_MAJOR" -lt 5 ] || ([ "$SWIFT_MAJOR" -eq 5 ] && [ "$SWIFT_MINOR" -lt 9 ]); then
    echo ""
    echo "Error: Swift 5.9 or newer is required."
    echo "Current version: $SWIFT_VERSION"
    echo ""
    echo "Update Xcode Command Line Tools:"
    echo "  sudo rm -rf /Library/Developer/CommandLineTools"
    echo "  xcode-select --install"
    exit 1
fi

echo "  ✓ macOS $(sw_vers -productVersion)"
echo "  ✓ Swift $SWIFT_VERSION"

echo ""
echo "=========================================="
echo "Installing AIControl CLI for Claude Code"
echo "=========================================="

# Build Swift CLI
echo ""
echo "[2/5] Building Swift CLI tool..."
swift build -c release --product AIControlCLI

# Install binary
echo ""
echo "[3/5] Installing aicontrol to /usr/local/bin..."
sudo cp .build/release/AIControlCLI /usr/local/bin/aicontrol
sudo chmod +x /usr/local/bin/aicontrol

# Install Claude Code skill
echo ""
echo "[4/5] Installing Claude Code skill..."
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
echo "[5/5] Verifying installation..."
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
