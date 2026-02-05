# FAFO Workflow Examples

This document provides practical workflow examples for the Computer Control skill.

## Basic Workflows

### 1. Take a Screenshot and Analyze

The most fundamental workflow - see what's on screen before acting.

```bash
# Capture the current screen
aicontrol capture --output /tmp/screen.png

# Use Read tool to view the screenshot
# Then identify coordinates of elements you want to interact with
```

### 2. Click a Button in an App

```bash
# First, capture with grid to help identify coordinates
aicontrol capture --grid --output /tmp/with_grid.png

# View the screenshot to find the button coordinates
# Then click at those coordinates
aicontrol click 450 320

# Verify the click worked
aicontrol capture --output /tmp/after_click.png
```

### 3. Open an Application and Type Text

```bash
# Open the app
aicontrol open-app "Notes"

# Wait a moment for it to open, then focus it
aicontrol focus-app "Notes"

# Type some text
aicontrol type "Meeting notes for today:"
aicontrol key return
aicontrol type "- First item"
```

## Intermediate Workflows

### 4. Copy Text from One App to Another

```bash
# Focus the source app
aicontrol focus-app "Safari"

# Select all and copy
aicontrol key a --command
aicontrol key c --command

# Switch to destination app
aicontrol focus-app "TextEdit"

# Paste
aicontrol key v --command
```

### 5. Navigate a Form

```bash
# Click the first field
aicontrol click 200 150

# Type in the first field
aicontrol type "John Doe"

# Tab to next field
aicontrol key tab

# Type in the second field
aicontrol type "john@example.com"

# Tab and continue
aicontrol key tab
aicontrol type "555-1234"

# Submit the form (assuming there's a submit button)
aicontrol key return
```

### 6. Scroll and Find Content

```bash
# Capture initial state
aicontrol capture --output /tmp/page1.png

# Scroll down to see more content
aicontrol scroll -5

# Capture again
aicontrol capture --output /tmp/page2.png

# Continue scrolling if needed
aicontrol scroll -5
aicontrol capture --output /tmp/page3.png
```

## Advanced Workflows

### 7. Drag and Drop

```bash
# Capture to identify source and destination
aicontrol capture --grid --output /tmp/before_drag.png

# Drag from source (100, 200) to destination (400, 200)
aicontrol drag 100 200 400 200

# Verify the drag worked
aicontrol capture --output /tmp/after_drag.png
```

### 8. Use Spotlight to Launch Apps

```bash
# Open Spotlight
aicontrol key space --command

# Type the app name
aicontrol type "Calculator"

# Press return to launch
aicontrol key return
```

### 9. Multi-Step Document Editing

```bash
# Open the document (assuming it's already created)
aicontrol open-app "TextEdit"
aicontrol focus-app "TextEdit"

# Open a file (Cmd+O)
aicontrol key o --command

# Type the filename in the dialog
aicontrol type "myfile.txt"
aicontrol key return

# Make edits - select all and replace
aicontrol key a --command
aicontrol type "New content for the file"

# Save the file
aicontrol key s --command
```

### 10. Browser Navigation

```bash
# Focus Safari
aicontrol focus-app "Safari"

# Open a new tab
aicontrol key t --command

# Go to address bar
aicontrol key l --command

# Type a URL
aicontrol type "https://example.com"
aicontrol key return

# Wait for page load, then capture
aicontrol capture --output /tmp/webpage.png
```

## Tips for Success

1. **Always capture first** - Never click blind. Take a screenshot to see where elements are.

2. **Use grid overlay** - When precision matters, use `--grid` to get coordinate references.

3. **Verify after actions** - Take a screenshot after important actions to confirm they worked.

4. **Add small delays** - For complex workflows, the natural delay between commands usually suffices, but be patient with slow-loading apps.

5. **Use keyboard shortcuts** - Often faster and more reliable than clicking through menus.

6. **Chain related commands** - Group related actions together for a coherent workflow.
