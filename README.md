# UIAccessibility.convertToScreenCoordinates Path Mutation Bug

## Summary

In iOS 18+, `UIAccessibility.convertToScreenCoordinates(_:in:)` unexpectedly mutates its input `UIBezierPath` in addition to returning a new path. The input path shouldn't be modified, but it gets transformed in-place, causing coordinate drift when the same path object is reused.

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

Starting in iOS 18, this API mutates the input path in addition to returning a converted copy.

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
_ = view.accessibilityPath  // Returns path at (100, 200) ✓
_ = view.accessibilityPath  // Returns path at (200, 400) ✗ Wrong!
_ = view.accessibilityPath  // Returns path at (300, 600) ✗ Accumulating!

// 4. The stored path has been mutated
print(path.bounds.origin)  // (300, 600) - was (0, 0)!
```

**Expected:** Returns a new path with screen coordinates; input path unchanged.
**Actual:** Returns a new path but also mutates the input path, causing coordinates to accumulate on each access.

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

**Mutation pattern:** Each access adds the view's screen offset to the input path:
```
coordinates_after_N_accesses = original + (N × screenOffset)

where:
  N = number of times accessibilityPath has been accessed (1, 2, 3, ...)
  screenOffset = view.convert(CGPoint.zero, to: nil)
```

**Trigger conditions** (all required):
- Most path types (see Visual Comparison section for specifics)
- View is in a key, visible window
- Called from within `accessibilityPath` getter
- Same path object reused across accesses

**Unaffected paths:** `UIBezierPath(rect:)`, `UIBezierPath(ovalIn:)`, and `UIBezierPath(arcCenter:...)` use optimized internal representations that avoid the bug. All other tested path types including `roundedRect` and `cgPath` constructions with explicit elements are affected.

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
  -scheme BugDemonstrationTests \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=18.5'
```

**Note:** The actual bug behavior with coordinate drift is best demonstrated by running the app itself and enabling VoiceOver. Unit tests document the bug patterns but don't reproduce the full mutation behavior since `UIAccessibility.convertToScreenCoordinates` doesn't perform actual coordinate conversion in test environments.

Key tests:
- `test_roundedRectPath_coordinatesDriftOnRepeatedReads()` - Canonical example from README
- `test_cgPathWithQuadCurve_coordinatesDriftOnRepeatedReads()` - CGPath with quadCurve affected
- `test_cgPathWithLines_coordinatesDriftOnRepeatedReads()` - CGPath with lines affected
- `test_rectPath_coordinatesStableOnRepeatedReads()` - rect is unaffected
- `test_ovalPath_coordinatesStableOnRepeatedReads()` - ovalIn is unaffected
- `test_arcCenterPath_coordinatesStableOnRepeatedReads()` - arcCenter is unaffected
- `test_detachedView_noCoordinateDrift()` - Window hierarchy requirement
- `test_workaround_copyPath_coordinatesStable()` - Confirms the workaround works
