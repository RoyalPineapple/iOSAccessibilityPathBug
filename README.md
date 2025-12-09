# UIAccessibility.convertToScreenCoordinates mutates input UIBezierPath on iOS 18+

## Summary

`UIAccessibility.convertToScreenCoordinates(_:in:)` mutates the input `UIBezierPath` in-place on iOS 18 and later. This violates the documented API contract which states it **"returns a new path object with the results"**.

> "Converts the specified path object to screen coordinates and **returns a new path object** with the results."
> — [Apple Developer Documentation](https://developer.apple.com/documentation/uikit/uiaccessibility/1615139-converttoscreencoordinates)

## Environment

- iOS 18.0+ (tested on 18.5 and 26.1)
- Does NOT occur on iOS 17.5 and earlier
- Xcode 16.4 / Xcode 26.1

## Steps to Reproduce

1. Create a `UIView` subclass that stores a `UIBezierPath` in local coordinates
2. Override `accessibilityPath` to convert the stored path using `UIAccessibility.convertToScreenCoordinates`
3. Read `accessibilityPath` multiple times

```swift
class CustomView: UIView {
    var relativePath: UIBezierPath?

    override var accessibilityPath: UIBezierPath? {
        get {
            guard let path = relativePath else { return nil }
            return UIAccessibility.convertToScreenCoordinates(path, in: self)
        }
        set { super.accessibilityPath = newValue }
    }
}
```

Alternatively, run the unit tests in this project:

```bash
# iOS 18 - FAILS
xcodebuild test -project iOS18AccessibilityBugRepro.xcodeproj \
  -scheme iOS18AccessibilityBugRepro \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=18.5' \
  -only-testing:iOS18AccessibilityBugReproTests/AccessibilityPathMutationTests

# iOS 17 - PASSES  
xcodebuild test -project iOS18AccessibilityBugRepro.xcodeproj \
  -scheme iOS18AccessibilityBugRepro \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro,OS=17.5' \
  -only-testing:iOS18AccessibilityBugReproTests/AccessibilityPathMutationTests
```

## Expected Results

Per the [documented behavior](https://developer.apple.com/documentation/uikit/uiaccessibility/1615139-converttoscreencoordinates), the method should return a new path object. The input path should not be modified.

Each read of `accessibilityPath` returns the same screen coordinates:

```
Read 1: origin=(100.0, 200.0)
Read 2: origin=(100.0, 200.0)
Read 3: origin=(100.0, 200.0)
Read 4: origin=(100.0, 200.0)
Read 5: origin=(100.0, 200.0)
```

## Actual Results

On iOS 18+, the input path is mutated in-place. Coordinates accumulate with each call:

```
Read 1: origin=(100.0, 200.0)   ← correct
Read 2: origin=(200.0, 400.0)   ← doubled
Read 3: origin=(300.0, 600.0)   ← tripled
Read 4: origin=(400.0, 800.0)   ← quadrupled
Read 5: origin=(500.0, 1000.0)  ← 5x
```

## Regression

| iOS Version | Result |
|-------------|--------|
| iOS 17.5    | ✅ PASS - input path not mutated |
| iOS 18.5    | ❌ FAIL - input path mutated |
| iOS 26.1    | ❌ FAIL - input path mutated |

## Workaround

Copy the path before calling `convertToScreenCoordinates`:

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
