#!/bin/bash
set -e

echo "=========================================="
echo "Installing AIControl CLI for Claude Code"
echo "=========================================="

# Build Swift CLI
echo ""
echo "[1/3] Building Swift CLI tool..."
swift build -c release --product AIControlCLI

# Install binary
echo ""
echo "[2/3] Installing aicontrol to /usr/local/bin..."
sudo cp .build/release/AIControlCLI /usr/local/bin/aicontrol
sudo chmod +x /usr/local/bin/aicontrol

# Verify installation
echo ""
echo "[3/3] Verifying installation..."
aicontrol --version

echo ""
echo "=========================================="
echo "Installation complete!"
echo "=========================================="
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
