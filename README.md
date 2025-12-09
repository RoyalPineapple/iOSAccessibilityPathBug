# iOS 18 UIAccessibility.convertToScreenCoordinates Mutation Bug

This project demonstrates a **regression in iOS 18** where `UIAccessibility.convertToScreenCoordinates(_:in:)` **mutates the input `UIBezierPath` in-place** instead of returning a new path with converted coordinates.

## The Bug

On iOS 18, each call to `convertToScreenCoordinates` adds the view's screen position to the input path's coordinates. This causes coordinates to accumulate with each call, breaking any code that:

1. Stores a relative `UIBezierPath` 
2. Converts it to screen coordinates in `accessibilityPath` getter
3. Has `accessibilityPath` read multiple times (e.g., by VoiceOver, accessibility inspector, or snapshot testing)

### Expected Behavior (iOS 17 and earlier)

```
Read 1: origin=(100.0, 200.0), ratio=1.0 ✅
Read 2: origin=(100.0, 200.0), ratio=1.0 ✅
Read 3: origin=(100.0, 200.0), ratio=1.0 ✅
Read 4: origin=(100.0, 200.0), ratio=1.0 ✅
Read 5: origin=(100.0, 200.0), ratio=1.0 ✅
```

### Actual Behavior (iOS 18)

```
Read 1: origin=(100.0, 200.0), ratio=1.0 ✅
Read 2: origin=(200.0, 400.0), ratio=2.0 ❌ BUG!
Read 3: origin=(300.0, 600.0), ratio=3.0 ❌ BUG!
Read 4: origin=(400.0, 800.0), ratio=4.0 ❌ BUG!
Read 5: origin=(500.0, 1000.0), ratio=5.0 ❌ BUG!
```

## Affected Code Pattern

This common pattern is broken on iOS 18:

```swift
class CustomAccessibilityView: UIView {
    var relativePath: UIBezierPath?

    override var accessibilityPath: UIBezierPath? {
        get {
            guard let path = relativePath else { return nil }
            // BUG: On iOS 18, this mutates `relativePath` in-place!
            return UIAccessibility.convertToScreenCoordinates(path, in: self)
        }
        set { super.accessibilityPath = newValue }
    }
}
```

## Workaround

Copy the path before calling `convertToScreenCoordinates`:

```swift
override var accessibilityPath: UIBezierPath? {
    get {
        guard let path = relativePath else { return nil }
        let pathCopy = path.copy() as! UIBezierPath  // FIX: Copy first
        return UIAccessibility.convertToScreenCoordinates(pathCopy, in: self)
    }
    set { super.accessibilityPath = newValue }
}
```

## Reproduction Steps

1. Open project in Xcode 16.x
2. Run tests on iOS 18.x simulator:
   ```bash
   xcodebuild test -project iOS18AccessibilityBugRepro.xcodeproj \
     -scheme iOS18AccessibilityBugRepro \
     -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=18.5' \
     -only-testing:iOS18AccessibilityBugReproTests/AccessibilityPathMutationTests
   ```
3. Observe `testAccessibilityPathMutationBug` **FAILS**
4. Run same tests on iOS 17.x simulator - **PASSES**

## Test Results

| iOS Version | testAccessibilityPathMutationBug | testConvertToScreenCoordinatesMutatesInput |
|-------------|----------------------------------|-------------------------------------------|
| iOS 17.5    | ✅ PASS                          | ✅ PASS                                    |
| iOS 18.5    | ❌ FAIL                          | ✅ PASS                                    |

## Environment

- Xcode 16.4
- iOS 18.5 Simulator
- iOS 17.5 Simulator (for comparison)

## Impact

This bug affects any app or library that:
- Uses custom `accessibilityPath` implementations
- Stores paths in local coordinates and converts on access
- Has accessibility paths read multiple times during the app lifecycle

This includes accessibility snapshot testing libraries and apps with custom accessible controls.
