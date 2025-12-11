# Apple Feedback: UIAccessibility.convertToScreenCoordinates Can Return Incorrect Coordinates When Called Repeatedly with Same CGPath

**Feedback Type:** Bug Report
**Area:** UIAccessibility API
**Reproducible:** Always

## Summary

`UIAccessibility.convertToScreenCoordinates(_:in:)` exhibits coordinate drift when called repeatedly with the same CGPath. This regression was introduced in iOS 18.0 and causes VoiceOver focus outlines to drift away from their intended positions. The function correctly creates new output paths as documented, but calculates their coordinates with accumulation errors: N× the screen offset, where N is the number of times that specific CGPath has been converted.

## Description

The `UIAccessibility.convertToScreenCoordinates(_:in:)` API is documented to "return a new path object" with coordinates converted to screen space. Starting in iOS 18.0, when called repeatedly with the same CGPath object, returned coordinates accumulate the screen offset multiple times: the 1st call returns correct coordinates, the 2nd call returns 2× the screen offset, the 3rd call returns 3× the screen offset, and so on. The input path parameter remains unchanged - the bug affects only the returned path's coordinates.

This breaks the implementation pattern for `accessibilityPath` where a single relative path is converted on each access. When a view's `accessibilityPath` getter is accessed multiple times (as happens during normal VoiceOver usage), the returned coordinates drift further from the correct position with each access. This manifests visually as VoiceOver focus outlines that are incorrectly positioned or completely off-screen.

## Steps to Reproduce

1. Create a UIView subclass that implements `accessibilityPath` using the following pattern:

```swift
class AccessibilityPathView: UIView {

    var relativePath: UIBezierPath?

    override var accessibilityPath: UIBezierPath? {
        get {
            guard let path = relativePath else { return nil }
            return UIAccessibility.convertToScreenCoordinates(path, in: self)
        }
        set { fatalError("use relativePath instead") }
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
let first = view.accessibilityPath   // bounds.origin.x = 100 ✓
let second = view.accessibilityPath  // bounds.origin.x = 200 ✗ (2× offset)
let third = view.accessibilityPath   // bounds.origin.x = 300 ✗ (3× offset)

// Input path remains unchanged - bug is in output calculation
print(path.bounds.origin)            // Still (0, 0)
print(first.bounds.origin)           // (100, 200) - correct
print(second.bounds.origin)          // (200, 400) - wrong!
print(third.bounds.origin)           // (300, 600) - wrong!
```

## Expected Results

- Each call to `convertToScreenCoordinates(_:in:)` should return a new path with correct screen coordinates (100, 200)
- Multiple accesses to `accessibilityPath` should return consistent, correct coordinates
- VoiceOver focus outlines should align correctly with their views

## Actual Results

- Each call to `convertToScreenCoordinates(_:in:)` returns a new path (as documented) but with incorrect coordinates
- Coordinates accumulate following the pattern: `returned = original + (N × screenOffset)` where N = 1, 2, 3... and screenOffset is the view's screen position
- Example: 1st=(100,200) ✓, 2nd=(200,400) ✗, 3rd=(300,600) ✗
- Multiple accesses to `accessibilityPath` return increasingly incorrect coordinates
- VoiceOver focus outlines drift away from their views or appear off-screen

## Configuration

**Affected Versions:**
- iOS 18.0 through iOS 26.1 (latest tested)
- Reproduced on both iOS Simulator and physical devices

**Last Tested Working Version:**
- iOS 17.5

**Affected Path Types:**
- `UIBezierPath(roundedRect:cornerRadius:)`
- `UIBezierPath(cgPath:)` with explicit path elements (lines, curves)
- Most path construction methods

**Unaffected Path Types:**
- `UIBezierPath(rect:)`
- `UIBezierPath(ovalIn:)`
- `UIBezierPath(arcCenter:radius:startAngle:endAngle:clockwise:)`

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

## Sample Project

A complete sample project demonstrating this issue is attached 

The project includes:
- Unit tests documenting the bug across different path types
- Before/after screenshots showing the visual impact
- Tests verifying the workaround

To run the demonstration tests:
```bash
xcodebuild test -project iOSAccessibilityPathBug.xcodeproj \
  -scheme AccessibilityBugTestHost \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=18.5' \
  -only-testing:BugDemonstrationTests
```

