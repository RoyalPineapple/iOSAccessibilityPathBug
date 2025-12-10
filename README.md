# UIAccessibility.convertToScreenCoordinates Path Mutation Bug

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

Starting in iOS 18, this API uses corrupted internal state when calculating the returned path's coordinates, causing accumulation errors on repeated calls.

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
**Actual:** Returns new paths with cumulative coordinate errors: 1st call correct, 2nd call has 2× offset, 3rd call has 3× offset. Input path remains unchanged (the bug is in output generation, not input mutation).

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
| iOS 18.0+ | Path mutation occurs |
| iOS 26.1 | Still present |

## Technical Details

**Observed behavior:** When called repeatedly with the same CGPath, `convertToScreenCoordinates()` returns new paths with coordinates that accumulate the screen offset multiple times. The input path is never modified - the bug affects only the returned path's coordinates.

**Accumulation pattern:**
```
returned_coordinates = original + (N × screenOffset)

where:
  N = number of times this specific CGPath has been converted (1, 2, 3, ...)
  screenOffset = view.convert(CGPoint.zero, to: nil)
```

**Confirmed through tests:**

*Input path behavior:*
- ✓ Input path object never changes (same reference, bounds, and CGPath pointer across all calls)
- ✓ Each call returns a NEW output path object (confirmed via distinct CGPath pointer addresses)

*Accumulation is per-CGPath:*
- ✓ Each unique CGPath accumulates independently
- ✓ Multiple views with different CGPaths show independent accumulation
- ✓ Creating fresh view objects doesn't prevent accumulation (same CGPath continues accumulating)

*Coordinate drift resets (returns to correct values) when:*
- ✓ New path object assigned (`path?.copy()` or new `UIBezierPath(...)`)
- ✓ CGPath is modified (`apply()`, `addLine()`, `close()`, etc.)

*Coordinate drift does NOT reset (continues accumulating) when:*
- ✓ Same path reference is reassigned without creating new object
- ✓ View moves to new position or changes hierarchy

*Path type behavior:*
- ✓ `UIBezierPath(rect:)`, `UIBezierPath(ovalIn:)`, and `UIBezierPath(arcCenter:...)` always return correct coordinates (no accumulation)
- ✓ After using rect/oval, switching to roundedRect starts accumulation fresh (no interaction between path types)
- ✓ All other tested types accumulate: `roundedRect`, CGPath with explicit elements (lines, curves)

**Trigger conditions** (all required):
- Affected path type (roundedRect, CGPath with explicit elements)
- View is in a key, visible window
- Multiple calls to function with same CGPath
- Called from within `accessibilityPath` getter

## Workaround

Copy the path before conversion to create a new path object:

```swift
override var accessibilityPath: UIBezierPath? {
    get {
        guard let path = relativePath?.copy() as? UIBezierPath else { return nil }
        return UIAccessibility.convertToScreenCoordinates(path, in: self)
    }
    set { super.accessibilityPath = newValue }
}
```

**Why this works:** Tests confirm that when a new path object is created (via `copy()` or modification), the next conversion returns correct coordinates instead of accumulated values. Since each `accessibilityPath` call creates a fresh copy, each conversion is the first call for that CGPath object and returns correct coordinates.

## Running the Tests

The test suite in `iOSAccessibilityPathBugTests/PathMutationDemonstration.swift` demonstrates the bug patterns and verifies the workaround:

```bash
xcodebuild test -project iOSAccessibilityPathBug.xcodeproj \
  -scheme BugDemonstrationTests \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=18.5'
```
