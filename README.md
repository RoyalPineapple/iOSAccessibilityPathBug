# UIAccessibility.convertToScreenCoordinates Coordinate Drift Bug

## Summary

In iOS 18+, `UIAccessibility.convertToScreenCoordinates(_:in:)` exhibits coordinate drift when called repeatedly with the same CGPath. The function creates new output paths (as documented) but calculates coordinates that accumulate N× the screen offset, where N is the number of times that specific CGPath has been converted.

**Observed in:** iOS 18.0 through iOS 26.1
**Last working version:** iOS 17.5

## Expected Behavior

Per Apple's documentation, `convertToScreenCoordinates(_:in:)` should "return a new path object" with converted coordinates. A standard pattern for implementing `accessibilityPath` is:

```swift
override var accessibilityPath: UIBezierPath? {
    get {
        guard let path = relativePath else { return nil }
        return UIAccessibility.convertToScreenCoordinates(path, in: self)
    }
}
```

Starting in iOS 18, when this API is called repeatedly with the same CGPath, the returned coordinates accumulate incorrectly.

## Minimal Reproduction

```swift
// 1. Implement accessibilityPath using the documented pattern
class AccessibilityPathView: UIView {
    var relativePath: UIBezierPath?

    override var accessibilityPath: UIBezierPath? {
        guard let path = relativePath else { return nil }
        return UIAccessibility.convertToScreenCoordinates(path, in: self)
    }
}

// 2. Add to visible window at position (100, 200)
let view = AccessibilityPathView(frame: CGRect(x: 100, y: 200, width: 60, height: 40))
let path = UIBezierPath(roundedRect: CGRect(x: 0, y: 0, width: 60, height: 40), cornerRadius: 10)
view.relativePath = path
window.addSubview(view)
window.makeKeyAndVisible()

// 3. Access the path multiple times
let first = view.accessibilityPath   // Returns path at (100, 200) ✓
let second = view.accessibilityPath  // Returns path at (200, 400) ✗ Wrong!
let third = view.accessibilityPath   // Returns path at (300, 600) ✗ Accumulating!

// 4. The input path remains unchanged
print(path.bounds.origin)  // Still (0, 0) - input never modified
print(first.bounds.origin) // (100, 200) - correct
print(second.bounds.origin) // (200, 400) - 2× screen offset
print(third.bounds.origin)  // (300, 600) - 3× screen offset
```

**Expected:** Returns a new path with screen coordinates (100, 200) on each call; input path unchanged.
**Actual:** Returns new paths with cumulative coordinate errors: 1st call correct, 2nd call has 2× offset, 3rd call has 3× offset. Input path remains unchanged - the bug affects only the returned coordinates.

### Visual Comparison

Screenshots generated with [AccessibilitySnapshot](https://github.com/cashapp/AccessibilitySnapshot) showing VoiceOver focus outlines:

| iOS 17.5 (Working) | iOS 18+ (Bug) |
|-------------------|---------------|
| ![iOS 17 Reference](testAccessibilityPaths_17_5_393x852@3x.png) | ![iOS 18 Bug](testAccessibilityPaths_18_5_402x874@3x.png) |
| All VoiceOver outlines correctly aligned with their views | **Cyan** outline drifted right; **Yellow** and **Purple** outlines completely off-screen.<br/>**Magenta**, **Green**, and **Blue** outlines remain correctly aligned (unaffected path types). |

**Affected path types:**
- **Cyan:** `UIBezierPath(roundedRect:cornerRadius:)` - visibly drifted
- **Yellow:** `UIBezierPath(cgPath:)` with quadCurve - off-screen
- **Purple:** `UIBezierPath(cgPath:)` with lines - off-screen

**Unaffected path types:**
- **Magenta:** `UIBezierPath(rect:)` - stable
- **Green:** `UIBezierPath(arcCenter:...)` - stable
- **Blue:** `UIBezierPath(ovalIn:)` - stable

## Version History

| iOS Version | Status |
|-------------|--------|
| iOS 17.5 | Works as documented |
| iOS 18.0+ | Coordinate drift bug present |
| iOS 26.1 | Still present |

## Bug Behavior

When called repeatedly with the same CGPath, `convertToScreenCoordinates()` returns incorrect coordinates that accumulate:

```
returned_coordinates = original + (N × screenOffset)

where:
  N = 1, 2, 3... (number of calls with this CGPath)
  screenOffset = view's position in screen coordinates
```

Example with view at screen position (100, 200):
- 1st call: correct coordinates (100, 200)
- 2nd call: 2× offset (200, 400)
- 3rd call: 3× offset (300, 600)

The bug affects `UIBezierPath(roundedRect:)` and CGPath with explicit elements (lines, curves). Simple paths like `rect`, `ovalIn`, and `arcCenter` work correctly.

## Workaround

Copy the path before conversion:

```swift
override var accessibilityPath: UIBezierPath? {
    get {
        guard let path = relativePath?.copy() as? UIBezierPath else { return nil }
        return UIAccessibility.convertToScreenCoordinates(path, in: self)
    }
    set { super.accessibilityPath = newValue }
}
```

## Running the Tests

The test suite in `iOSAccessibilityPathBugTests/PathMutationDemonstration.swift` demonstrates the bug patterns and verifies the workaround:

```bash
xcodebuild test -project iOSAccessibilityPathBug.xcodeproj \
  -scheme AccessibilityBugTestHost \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=18.5' \
  -only-testing:BugDemonstrationTests
```
