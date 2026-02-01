# SwiftUI TextField Keyboard Input Fix for NSHostingView

## Problem Summary
SwiftUI TextField inside NSHostingView shows visual focus (blue border) but doesn't accept keyboard input. This is a known issue on macOS 15+ with several root causes.

## Root Causes

### 1. NSWindow Key/Main Status
Windows with non-standard levels (like `.floating`) or custom configurations may not properly become key windows, which prevents keyboard events from reaching SwiftUI views.

### 2. NSHostingView Event Handling Bug (macOS 15+)
NSHostingView has a bug where event handling areas become misaligned if SwiftUI views use position modifiers (`.position()`, `.offset()` with absolute coordinates).

### 3. First Responder Chain
`makeFirstResponder(window.contentView)` may not properly reach the actual TextField inside the SwiftUI hierarchy.

## Solutions (In Order of Recommendation)

### Solution 1: Custom NSWindow Subclass ⭐ RECOMMENDED

**What it does:** Overrides `canBecomeKey` and `canBecomeMain` to ensure the window can receive keyboard events.

**Implementation:**
```swift
class FocusableWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}
```

**Usage:**
```swift
let window = FocusableWindow(
    contentRect: NSRect(x: 0, y: 0, width: 1280, height: 720),
    styleMask: [.titled, .closable, .resizable],
    backing: .buffered,
    defer: false
)
```

**Status:** ✅ Already applied to `/Users/frank/Desktop/CodingProjects/FAFO/AIComputerControl.swift`

---

### Solution 2: Avoid Position Modifiers in SwiftUI

**What to avoid:**
- `.position(x:y:)` with absolute coordinates
- `.offset(x:y:)` with large values
- Setting frame positions within SwiftUI views

**What to do instead:**
- Only set `.frame(width:height:)` in SwiftUI
- Set NSHostingView's frame for positioning
- Use relative layout (padding, spacing)

**Status:** ✅ Verified - your code is already safe

---

### Solution 3: NSViewRepresentable TextField (Fallback)

**When to use:** If Solutions 1 & 2 don't work, use this bulletproof approach.

**Implementation:** See `/Users/frank/Desktop/CodingProjects/FAFO/FocusableTextField.swift`

**Usage:**
```swift
FocusableTextField(
    placeholder: "Type here...",
    text: $taskInput,
    onSubmit: submitTask,
    isFocused: isInputFocused
)
```

**Pros:**
- Direct AppKit access, guaranteed to work
- Full control over focus behavior
- No SwiftUI TextField bugs

**Cons:**
- More boilerplate code
- Loses some SwiftUI features
- Requires manual styling

---

### Solution 4: Window Level Timing Fix

**Issue:** Changing window level after creation can break focus.

**Fix:** Re-establish key status after changing level:
```swift
window.level = .floating
DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
    window.level = .normal
    window.makeKeyAndOrderFront(nil) // Re-establish
}
```

**Status:** ✅ Already applied to your code

---

## Testing

Run the test app to verify the fix works:

```bash
cd /Users/frank/Desktop/CodingProjects/FAFO
swift TestTextFieldFocus.swift
```

**Expected result:**
- Window opens
- Click in text field
- Type - text should appear
- If it works, Solution 1 is sufficient!

---

## Integration Checklist

✅ **Step 1:** FocusableWindow subclass created
✅ **Step 2:** CanvasWindowController updated to use FocusableWindow
✅ **Step 3:** Window level timing fixed
✅ **Step 4:** TextField has minHeight frame (prevents event misalignment)
⬜ **Step 5:** Test with `swift TestTextFieldFocus.swift`
⬜ **Step 6:** Test in main app `swift AIComputerControl.swift`

If Step 5/6 still show issues, proceed to Solution 3 (NSViewRepresentable).

---

## Additional Debugging

If the issue persists, check:

1. **NSApp activation:**
   ```swift
   NSApp.activate(ignoringOtherApps: true)
   window.makeKeyAndOrderFront(nil)
   ```

2. **First responder status:**
   ```swift
   print("Is key window:", window.isKeyWindow)
   print("First responder:", window.firstResponder)
   ```

3. **Event monitoring:**
   ```swift
   NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
       print("Key event received:", event)
       return event
   }
   ```

4. **Focus state debugging:**
   ```swift
   TextField("...", text: $text)
       .focused($isFocused)
       .onChange(of: isFocused) { newValue in
           print("Focus changed:", newValue)
       }
   ```

---

## References & Sources

- [NSHostingView Not Working With SwiftUI](https://developer.apple.com/forums/thread/759081) - Apple Developer Forums thread documenting the event handling offset issue
- [How to make TextField focus in SwiftUI for macOS](https://github.com/onmyway133/blog/issues/620) - Community solutions including canBecomeKey override
- [SwiftUI TextField focus/firstResponder (macOS)](https://forums.swift.org/t/swiftui-textfield-focus-firstresponder-macos/35018) - Swift Forums discussion on TextField focus issues
- [macOS programming: Implementing a focusable text field in SwiftUI](https://serialcoder.dev/text-tutorials/macos-tutorials/macos-programming-implementing-a-focusable-text-field-in-swiftui/) - NSViewRepresentable approach

---

## Quick Reference

**Problem:** TextField shows focus but won't accept typing
**Primary Fix:** Use `FocusableWindow` subclass with `canBecomeKey` override
**Fallback Fix:** Use `FocusableTextField` (NSViewRepresentable)
**Test File:** `TestTextFieldFocus.swift`
**Files Modified:**
- `/Users/frank/Desktop/CodingProjects/FAFO/AIComputerControl.swift`
- `/Users/frank/Desktop/CodingProjects/FAFO/TaskSystem.swift`

**Files Created:**
- `/Users/frank/Desktop/CodingProjects/FAFO/FocusableTextField.swift`
- `/Users/frank/Desktop/CodingProjects/FAFO/TestTextFieldFocus.swift`
- `/Users/frank/Desktop/CodingProjects/FAFO/TEXTFIELD_FIX_GUIDE.md`
