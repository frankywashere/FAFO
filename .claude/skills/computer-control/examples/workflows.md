# Computer Control Workflow Examples

Practical workflow examples for common automation tasks using `aicontrol`.

---

## 1. Taking and Viewing a Screenshot

Capture the current screen state and view it to understand the UI layout.

```bash
aicontrol capture --output /tmp/screen.png
```

Then use the Read tool to view the screenshot:
```
Read /tmp/screen.png
```

The screenshot shows the current display state and can be used to identify coordinates for clicking or to verify that previous actions completed successfully.

---

## 2. Opening Safari and Navigating to a URL

Open Safari browser, focus the address bar, type a URL, and navigate to it.

```bash
# Open Safari application
aicontrol open-app Safari

# Wait for the app to launch
sleep 1

# Focus the address bar (Cmd+L)
aicontrol key l --command

# Type the URL
aicontrol type "https://example.com"

# Press Enter to navigate
aicontrol key return
```

---

## 3. Clicking on a Specific UI Element

Use a screenshot to identify the target location, then click on it.

```bash
# Step 1: Capture the screen to see current state
aicontrol capture --output /tmp/before-click.png
```

View the screenshot with the Read tool to identify the X,Y coordinates of the element you want to click.

```bash
# Step 2: Click at the identified coordinates
aicontrol click 450 320

# Step 3: Capture again to verify the click worked
aicontrol capture --output /tmp/after-click.png
```

View the after screenshot to confirm the expected change occurred.

---

## 4. Copy and Paste Workflow

Select content, copy it to clipboard, move to a new location, and paste.

```bash
# Select all content in the current app (Cmd+A)
aicontrol key a --command

# Copy to clipboard (Cmd+C)
aicontrol key c --command

# Click somewhere else (e.g., another text field or app)
aicontrol click 600 400

# Paste from clipboard (Cmd+V)
aicontrol key v --command
```

---

## 5. Working with TextEdit

Open TextEdit, create a new document, and type some text.

```bash
# Open the TextEdit application
aicontrol open-app TextEdit

# Ensure TextEdit is the active (frontmost) app
aicontrol focus-app TextEdit

# Create a new document (Cmd+N)
aicontrol key n --command

# Wait briefly for the new document window
sleep 0.5

# Type text into the document
aicontrol type "Hello world"
```

---

## 6. Drag and Drop

Move an item from one position to another using drag and drop.

```bash
# Capture the screen to identify source and destination positions
aicontrol capture --output /tmp/drag-start.png
```

View the screenshot to identify:
- Source position (where to start the drag)
- Destination position (where to drop)

```bash
# Drag from (100, 100) to (500, 500)
aicontrol drag 100 100 500 500

# Verify the drag completed successfully
aicontrol capture --output /tmp/drag-end.png
```

---

## Important Notes

### Always Verify with Screenshots

After performing actions, capture a screenshot to verify the expected result:
```bash
aicontrol capture --output /tmp/verify.png
```

This is especially important for:
- Confirming an app opened successfully
- Verifying a click landed on the intended target
- Checking that typed text appeared correctly
- Ensuring drag and drop moved the item

### Use focus-app Before Typing or Clicking

Before sending keystrokes or clicks to a specific application, ensure it is the active app:
```bash
aicontrol focus-app AppName
```

This prevents keystrokes from going to the wrong application.

### Add Sleep Between Rapid Operations

Some operations need time to complete before the next action. Add `sleep` commands when:
- Launching applications (they need time to fully open)
- After clicking buttons that trigger UI changes
- Between rapid typing and clicking sequences

```bash
aicontrol open-app Notes
sleep 1  # Wait for Notes to fully launch
aicontrol key n --command
sleep 0.5  # Wait for new note dialog
aicontrol type "My note content"
```

### Coordinate System

Coordinates used by `aicontrol` are display points, which correspond directly to screenshot pixel positions. When you identify a position in a screenshot (e.g., the center of a button at pixel 450, 320), use those same values for click or drag commands:

```bash
# If button center is at pixel (450, 320) in the screenshot
aicontrol click 450 320
```
