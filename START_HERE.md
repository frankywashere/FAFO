# AIControl CLI - Quick Start Guide

A command-line tool that gives Claude Code direct control of your Mac - screen capture, mouse, and keyboard.

## Installation

```bash
./install.sh
```

This builds the CLI and installs it to `/usr/local/bin/aicontrol`.

If you don't have sudo access, you can run directly from the build:
```bash
swift build -c release --product AIControlCLI
.build/release/AIControlCLI --help
```

## Permissions Required

You need to grant these permissions (you likely already have them if the old version worked):

1. **Screen Recording**: System Settings → Privacy & Security → Screen Recording
2. **Accessibility**: System Settings → Privacy & Security → Accessibility

To check if permissions are granted:
```bash
aicontrol status
```

## Basic Commands

### Capture Screenshot
```bash
aicontrol capture --output /tmp/screen.png
aicontrol capture --grid    # With coordinate grid overlay
```

### Mouse Control
```bash
aicontrol click 500 300           # Left click at (500, 300)
aicontrol right-click 500 300     # Right click
aicontrol double-click 500 300    # Double click
aicontrol move-mouse 500 300      # Move cursor
aicontrol drag 100 100 500 500    # Drag from (100,100) to (500,500)
```

### Keyboard Control
```bash
aicontrol type "Hello world"      # Type text
aicontrol key return              # Press Enter
aicontrol key l --command         # Press Cmd+L
aicontrol key c --command         # Press Cmd+C (copy)
aicontrol key v --command         # Press Cmd+V (paste)
aicontrol key a --command --shift # Press Cmd+Shift+A
```

### Application Control
```bash
aicontrol open-app Safari         # Open Safari
aicontrol focus-app Chrome        # Bring Chrome to front
aicontrol show-desktop            # Toggle show desktop
```

### Calibration & Status
```bash
aicontrol calibrate               # Test coordinate accuracy
aicontrol status                  # Check permissions and display info
```

## How It Works

1. All coordinates use **display points** (not retina pixels)
2. Screenshot coordinates match click coordinates 1:1
3. All commands output JSON for easy parsing
4. Zero calibration error - coordinates are pixel-perfect

## Example: Navigate to a Website

```bash
aicontrol open-app Safari
sleep 1
aicontrol key l --command         # Focus address bar
aicontrol type "https://example.com"
aicontrol key return
```

## Troubleshooting

**"Permission denied" errors:**
- Grant Screen Recording permission for screen capture
- Grant Accessibility permission for mouse/keyboard control

**Coordinates seem off:**
- Run `aicontrol calibrate` to verify accuracy
- Ensure you're using display points, not pixels

**App not responding to input:**
- Use `aicontrol focus-app AppName` first
- Some apps may block programmatic input
