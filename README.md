# UIAccessibility.convertToScreenCoordinates mutates input UIBezierPath on iOS 18+

## Summary

`UIAccessibility.convertToScreenCoordinates(_:in:)` mutates the input `UIBezierPath` in-place on iOS 18 and later when called via an `accessibilityPath` getter while the view is in a key/visible window. This violates the documented API contract.

> "Converts the specified path object to screen coordinates and **returns a new path object** with the results."
> — [Apple Developer Documentation](https://developer.apple.com/documentation/uikit/uiaccessibility/1615139-converttoscreencoordinates)

## Bug Conditions

The bug requires ALL of these conditions:
1. **Path type**: Path built with explicit elements (`addLine`, `addCurve`, `roundedRect`, etc.)
2. **Window hierarchy**: View must be in a **key and visible** window
3. **Access method**: Called via `accessibilityPath` getter (direct API calls work correctly!)
4. **Path reuse**: Same path object used across multiple reads

## Path Types

### Works Correctly
| Path Type | Notes |
|-----------|-------|
| `UIBezierPath(rect:)` | Optimized internal representation |
| `UIBezierPath(ovalIn:)` | Optimized internal representation |
| `UIBezierPath(arcCenter:...)` | Optimized internal representation |
| `CGPath(rect:)` → `UIBezierPath(cgPath:)` | CGPath rect also works |
| Empty path | No elements to mutate |

### Has Bug
| Path Type | Notes |
|-----------|-------|
| `UIBezierPath(roundedRect:cornerRadius:)` | Uses curves internally |
| `path.move(to:)` / `path.addLine(to:)` | Explicit elements |
| `path.addQuadCurve(...)` / `path.addCurve(...)` | Explicit elements |
| Any path with `.reversing()` applied | Converts to explicit elements |
| `rect.append(linePath)` or `rect.addLine(...)` | Adding explicit element breaks it |

## Window Hierarchy Requirements

| Scenario | Bug Triggered? |
|----------|---------------|
| View not in any hierarchy | ✅ No bug |
| View in detached hierarchy (no window) | ✅ No bug |
| View in window that's not key/visible | ✅ No bug |
| View in key/visible window | ❌ **BUG** |
| Direct `convertToScreenCoordinates` call (not via getter) | ✅ No bug |

## What Doesn't Matter

These do NOT prevent the bug:
- `isAccessibilityElement` setting
- `accessibilityElementsHidden`
- View type (UIView, UILabel, UIButton)
- View transforms (rotation, scale, translation)
- ScrollView containment
- Hidden views / zero alpha
- Clipped views
- Deep nesting
- Layout timing

## Workarounds

### Option 1: Copy the path (recommended)
```swift
override var accessibilityPath: UIBezierPath? {
    get {
        guard let path = relativePath else { return nil }
        let pathCopy = path.copy() as! UIBezierPath
        return UIAccessibility.convertToScreenCoordinates(pathCopy, in: self)
    }
    set { super.accessibilityPath = newValue }
}
```

### Option 2: Create fresh path each time
```swift
override var accessibilityPath: UIBezierPath? {
    get {
        // Create new path each time instead of storing
        let path = UIBezierPath()
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: bounds.width, y: bounds.height))
        return UIAccessibility.convertToScreenCoordinates(path, in: self)
    }
    set { super.accessibilityPath = newValue }
}
```

### Option 3: Use rect/oval initializers if possible
```swift
// This works without copying:
let path = UIBezierPath(rect: bounds)  // ✅ No bug
let path = UIBezierPath(ovalIn: bounds)  // ✅ No bug
```

## Running the Tests

```bash
# iOS 18 - Many tests fail
xcodebuild test -project iOS18AccessibilityBugRepro.xcodeproj \
  -scheme iOS18AccessibilityBugRepro \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=18.5'

# iOS 17 - All tests pass
xcodebuild test -project iOS18AccessibilityBugRepro.xcodeproj \
  -scheme iOS18AccessibilityBugRepro \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro,OS=17.5'
```

## Regression Status

| iOS Version | Status |
|-------------|--------|
| iOS 17.5 | ✅ All tests pass |
| iOS 18.5 | ❌ Bug present |
| iOS 26.1 | ❌ Bug still present |
