# Apple Feedback: UIAccessibility.convertToScreenCoordinates Mutates Input Path

**Feedback Type:** Bug Report
**Area:** Accessibility
**Reproducible:** Always

## Summary

`UIAccessibility.convertToScreenCoordinates(_:in:)` can unexpectedly mutate its input `UIBezierPath` parameter in addition to returning a converted path. This regression was introduced in iOS 18.0 and causes VoiceOver focus outlines to drift away from their intended positions when the same path object is reused.

## Description

The `UIAccessibility.convertToScreenCoordinates(_:in:)` API is documented to "return a new path object" with coordinates converted to screen space. However, starting in iOS 18.0, the API modifies the input path in-place, causing the input path's coordinates to accumulate with each call. This breaks the standard implementation pattern for `accessibilityPath` where a single relative path is converted on each access.

When a view's `accessibilityPath` getter is accessed multiple times (as happens during normal VoiceOver usage), the returned coordinates drift further from the correct position with each access. This manifests visually as VoiceOver focus outlines that are incorrectly positioned or completely off-screen.

## Steps to Reproduce

1. Create a UIView subclass that implements `accessibilityPath` using the documented pattern:

```swift
class AccessibilityPathView: UIView {
    var relativePath: UIBezierPath?

    override var accessibilityPath: UIBezierPath? {
        guard let path = relativePath else { return nil }
        return UIAccessibility.convertToScreenCoordinates(path, in: self)
    }
}
```

2. Create a view instance with a `roundedRect` path and add it to a key, visible window:

```swift
let view = AccessibilityPathView(frame: CGRect(x: 100, y: 200, width: 60, height: 40))
let path = UIBezierPath(roundedRect: CGRect(x: 0, y: 0, width: 60, height: 40), cornerRadius: 10)
view.relativePath = path
window.addSubview(view)
window.makeKeyAndVisible()
```

3. Access `view.accessibilityPath` multiple times:

```swift
let first = view.accessibilityPath   // bounds.origin.x = 100
let second = view.accessibilityPath  // bounds.origin.x = 200
let third = view.accessibilityPath   // bounds.origin.x = 300
print(path.bounds.origin)            // (300, 600) - was (0, 0)!
```

## Expected Results

- Each call to `convertToScreenCoordinates(_:in:)` should return a new path with screen coordinates
- The input path parameter should remain unchanged
- Multiple accesses to `accessibilityPath` should return consistent screen coordinates
- VoiceOver focus outlines should align correctly with their views

## Actual Results

- Each call to `convertToScreenCoordinates(_:in:)` mutates the input path in-place
- The input path's coordinates accumulate: `coordinates_after_N_accesses = original + (N × screenOffset)`
- Multiple accesses to `accessibilityPath` return increasingly incorrect coordinates
- VoiceOver focus outlines drift away from their views or appear off-screen

## Configuration

**Affected Versions:**
- iOS 18.0 through iOS 26.1 (latest tested)
- Reproduced on both iOS Simulator and physical devices

**Last Working Version:**
- iOS 17.5

**Affected Path Types:**
- `UIBezierPath(roundedRect:cornerRadius:)`
- `UIBezierPath(cgPath:)` with explicit path elements (lines, curves)
- Most path construction methods

**Unaffected Path Types:**
- `UIBezierPath(rect:)`
- `UIBezierPath(ovalIn:)`
- `UIBezierPath(arcCenter:radius:startAngle:endAngle:clockwise:)`

**Trigger Conditions** (all required):
- View must be in a key, visible window hierarchy
- API called from within `accessibilityPath` getter
- Same path object reused across multiple accesses

## Workaround

Copy the path before conversion to prevent mutation:

```swift
override var accessibilityPath: UIBezierPath? {
    get {
        guard let path = relativePath?.copy() as? UIBezierPath else { return nil }
        return UIAccessibility.convertToScreenCoordinates(path, in: self)
    }
    set { super.accessibilityPath = newValue }
}
```

## Sample Project

A complete sample project demonstrating this issue is available at:
https://github.com/RoyalPineapple/iOSAccessibilityPathBug

The project includes:
- Minimal reproduction in the app with visual demonstration via VoiceOver
- Unit tests documenting the bug across different path types
- Before/after screenshots showing the visual impact
- Tests verifying the workaround

To run the demonstration tests:
```bash
xcodebuild test -project iOSAccessibilityPathBug.xcodeproj \
  -scheme BugDemonstrationTests \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=18.5'
```

## Additional Notes

This regression has significant impact on apps using custom accessibility paths, as VoiceOver users will encounter incorrectly positioned focus indicators that do not align with the actual interactive elements. The issue occurs in normal VoiceOver usage as the system queries `accessibilityPath` multiple times during navigation.
