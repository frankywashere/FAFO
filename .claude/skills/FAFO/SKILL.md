---
name: FAFO
description: Use this skill for direct computer control - taking screenshots, mouse clicks, keyboard input, app management, scrolling, dragging, and desktop automation via the aicontrol CLI.
allowed-tools:
  - Bash(aicontrol *)
  - Read
---

# Computer Control Skill

Control the macOS desktop directly using the `aicontrol` CLI. This enables taking screenshots, clicking, typing, scrolling, and managing applications.

## Commands

### Screen Capture
```bash
aicontrol capture                    # Capture screenshot to default path
aicontrol capture --grid             # Capture with coordinate grid overlay
aicontrol capture --output /path.png # Capture to specific path
```

### Mouse Actions
```bash
aicontrol click X Y                  # Left click at coordinates
aicontrol right-click X Y            # Right click at coordinates
aicontrol double-click X Y           # Double click at coordinates
aicontrol move-mouse X Y             # Move cursor without clicking
aicontrol drag X1 Y1 X2 Y2           # Drag from (X1,Y1) to (X2,Y2)
aicontrol scroll AMOUNT              # Scroll vertically (positive=up, negative=down)
aicontrol scroll AMOUNT --horizontal # Scroll horizontally
```

### Keyboard Input
```bash
aicontrol type "Hello world"         # Type text string
aicontrol key return                 # Press a key
aicontrol key c --command            # Cmd+C (copy)
aicontrol key v --command            # Cmd+V (paste)
aicontrol key a --command --shift    # Cmd+Shift+A
aicontrol key tab --option           # Option+Tab
```

Common key names: `return`, `escape`, `tab`, `space`, `delete`, `up`, `down`, `left`, `right`, `f1`-`f12`

### Application Control
```bash
aicontrol open-app "Safari"          # Open an application
aicontrol focus-app "Safari"         # Bring app to foreground
aicontrol show-desktop               # Show desktop (hide all windows)
```

### System
```bash
aicontrol status                     # Check system status and permissions
aicontrol calibrate                  # Calibrate coordinate system
```

## Important Notes

- **Coordinates**: All X,Y values are display points matching screenshot pixels (1:1 mapping)
- **JSON Output**: All commands return JSON with status and details
- **Screenshot First**: Always capture a screenshot before acting to see current state
- **View Screenshots**: Use the Read tool to view captured PNG files
- **Verify Actions**: Capture another screenshot after actions to confirm success

## Workflow

1. **Capture** - Take a screenshot to see the current screen state
2. **Analyze** - View the screenshot with Read tool, identify target coordinates
3. **Act** - Execute the appropriate command (click, type, etc.)
4. **Verify** - Capture another screenshot to confirm the action worked

Example:
```bash
# 1. See what's on screen
aicontrol capture --output /tmp/before.png

# 2. View it (use Read tool on /tmp/before.png)

# 3. Click the target element at identified coordinates
aicontrol click 500 300

# 4. Verify the result
aicontrol capture --output /tmp/after.png
```

## Common Patterns

### Open App and Type
```bash
aicontrol open-app "TextEdit"
aicontrol focus-app "TextEdit"
aicontrol type "Hello from Claude"
```

### Click a UI Element
```bash
aicontrol capture --grid --output /tmp/screen.png
# View screenshot, identify button at (400, 250)
aicontrol click 400 250
```

### Keyboard Shortcuts
```bash
aicontrol key s --command            # Save (Cmd+S)
aicontrol key z --command            # Undo (Cmd+Z)
aicontrol key q --command            # Quit (Cmd+Q)
aicontrol key space --command        # Spotlight (Cmd+Space)
aicontrol key tab --command          # Switch apps (Cmd+Tab)
```

### Select and Copy Text
```bash
aicontrol click 100 200              # Click start position
aicontrol key a --command            # Select all
aicontrol key c --command            # Copy
```

### Scroll Through Content
```bash
aicontrol scroll -5                  # Scroll down 5 units
aicontrol scroll 10                  # Scroll up 10 units
aicontrol scroll -3 --horizontal     # Scroll right
```
