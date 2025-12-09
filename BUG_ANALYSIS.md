# iOS 18 UIAccessibility.convertToScreenCoordinates Bug Analysis

## Executive Summary

`UIAccessibility.convertToScreenCoordinates(_:in:)` on iOS 18+ mutates the input `UIBezierPath` in place while also returning a new path object. This violates the documented API contract and causes accumulated transforms on repeated calls.

## Bug Behavior

### The Formula

```
output(N).origin = originalPath.origin + (N × screenOffset)
```

Where:
- **N** = the Nth call to `convertToScreenCoordinates` with that specific path object
- **screenOffset** = `view.convert(CGPoint.zero, to: nil)` (view's position in screen coordinates)
- **originalPath** = the path's state before any calls

### Example

```swift
let path = UIBezierPath()
path.move(to: CGPoint(x: 0, y: 0))
path.addLine(to: CGPoint(x: 10, y: 10))

let view = UIView(frame: CGRect(x: 100, y: 200, width: 60, height: 40))
// screenOffset = (100, 200)

// Call 1: output.origin = (0,0) + 1×(100,200) = (100, 200) ✓ correct
// Call 2: output.origin = (0,0) + 2×(100,200) = (200, 400) ✗ wrong!
// Call 3: output.origin = (0,0) + 3×(100,200) = (300, 600) ✗ wrong!
```

## Internal Mechanism

### Object Relationships

```
                                 ┌─────────────────┐
                                 │ Output          │
                                 │ UIBezierPath    │ ◄── NEW object
                                 │ (different ptr) │
                                 └────────┬────────┘
                                          │
                                          ▼
┌─────────────────┐              ┌─────────────────┐
│ Input           │              │ CGPath          │
│ UIBezierPath    │──────────────│ (transformed    │ ◄── MUTATED in place
│ (same ptr)      │  points to   │  in place)      │
└─────────────────┘    same      └─────────────────┘
```

### What the API Does Internally

1. Takes input `UIBezierPath`
2. Creates a NEW `UIBezierPath` for output
3. **BUG:** Mutates the input's underlying `CGPath` in place (applies screen transform to each point)
4. Returns the new path (which references the now-transformed CGPath)

### What We Verified

| Check | Result |
|-------|--------|
| Output is same UIBezierPath as input? | **NO** - different objects |
| Input and output share CGPath? | **NO** - separate storage |
| Modifying output changes input? | **NO** - independent |
| `UIBezierPath.apply()` called? | **NO** - bypassed |
| `cgPath` setter called? | **NO** - bypassed |
| Input's CGPath elements mutated? | **YES** - transformed in place |

## Affected Path Types

### Bug Present (explicit path elements)

| Path Type | Example |
|-----------|---------|
| `addLine(to:)` | `path.addLine(to: point)` |
| `addQuadCurve(to:controlPoint:)` | Quadratic curves |
| `addCurve(to:controlPoint1:controlPoint2:)` | Cubic curves |
| `UIBezierPath(roundedRect:cornerRadius:)` | Uses curves internally |
| Any path with `.reversing()` | Converts to explicit elements |

### Bug Absent (optimized representations)

| Path Type | Example |
|-----------|---------|
| `UIBezierPath(rect:)` | Simple rectangle |
| `UIBezierPath(ovalIn:)` | Ellipse/circle |
| `UIBezierPath(arcCenter:...)` | Arc segments |
| `CGPath(rect:)` → `UIBezierPath(cgPath:)` | CGPath rectangle |

## Conditions Required

All of these must be true for the bug to manifest:

1. **Path type**: Built with explicit elements (addLine, addCurve, etc.)
2. **Window hierarchy**: View must be in a **key and visible** window
3. **Access method**: Called via `accessibilityPath` getter
4. **Path reuse**: Same path object used across multiple reads

### Special Case: View at Origin

If the view is at screen position `(0, 0)`, the `screenOffset` is `(0, 0)`, so no mutation occurs regardless of path type.

## Manipulating the Output

### Predicting Output

Given:
- Original path origin: `(ox, oy)`
- Screen offset: `(sx, sy)`
- Call number: `N`

```swift
predictedOutput.origin.x = ox + (N × sx)
predictedOutput.origin.y = oy + (N × sy)
```

### Getting a Specific Output

To get output at target position `(tx, ty)`:

```swift
// Solve for N
let N_x = (tx - ox) / sx
let N_y = (ty - oy) / sy

// N must be a positive integer and same for both axes
if N_x == N_y && N_x > 0 && N_x == floor(N_x) {
    // Call API Int(N_x) times to get output at (tx, ty)
}
```

### Reversing the Mutation

If you know how many times the path was mutated:

```swift
// After N calls, reverse with:
let reverseTransform = CGAffineTransform(
    translationX: -CGFloat(N) * screenOffset.x,
    translationY: -CGFloat(N) * screenOffset.y
)
path.apply(reverseTransform)
// Path is now back to original
```

## Workarounds

### Option 1: Copy Before Each Call (Recommended)

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

### Option 2: Create Fresh Path Each Time

```swift
override var accessibilityPath: UIBezierPath? {
    get {
        // Recreate path from source data each time
        let path = UIBezierPath()
        path.move(to: startPoint)
        path.addLine(to: endPoint)
        return UIAccessibility.convertToScreenCoordinates(path, in: self)
    }
    set { super.accessibilityPath = newValue }
}
```

### Option 3: Use Non-Affected Path Types

```swift
// Instead of:
let path = UIBezierPath()
path.addRect(bounds)  // ❌ explicit elements

// Use:
let path = UIBezierPath(rect: bounds)  // ✅ optimized representation
```

## Regression History

| iOS Version | Status |
|-------------|--------|
| iOS 17.5 | ✅ Works correctly |
| iOS 18.0+ | ❌ Bug present |
| iOS 26.0 (beta) | ❌ Bug still present |

## References

- [Apple Documentation](https://developer.apple.com/documentation/uikit/uiaccessibility/1615139-converttoscreencoordinates): "Converts the specified path object to screen coordinates and **returns a new path object** with the results."
- Radar: FB[XXXXXX] (pending)
