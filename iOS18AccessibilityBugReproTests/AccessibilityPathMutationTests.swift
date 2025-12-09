import XCTest
import UIKit

/// A view that stores a relative path and converts it to screen coordinates.
/// BUG: On iOS 18, each access causes the stored path to be mutated.
private class BuggyAccessibilityPathView: UIView {
    var relativePath: UIBezierPath?

    override var accessibilityPath: UIBezierPath? {
        get {
            guard let path = relativePath else { return nil }
            return UIAccessibility.convertToScreenCoordinates(path, in: self)
        }
        set { super.accessibilityPath = newValue }
    }
}

/// Workaround: Copy the path BEFORE calling convertToScreenCoordinates.
private class FixedAccessibilityPathView: UIView {
    var relativePath: UIBezierPath?

    override var accessibilityPath: UIBezierPath? {
        get {
            guard let path = relativePath else { return nil }
            let pathCopy = path.copy() as! UIBezierPath
            return UIAccessibility.convertToScreenCoordinates(pathCopy, in: self)
        }
        set { super.accessibilityPath = newValue }
    }
}

final class AccessibilityPathMutationTests: XCTestCase {
    var window: UIWindow!
    var testView: UIView!

    override func setUp() {
        super.setUp()
        window = UIWindow(frame: CGRect(x: 0, y: 0, width: 400, height: 800))
        testView = UIView(frame: window.bounds)
        window.addSubview(testView)
        window.makeKeyAndVisible()
    }

    override func tearDown() {
        window.isHidden = true
        window = nil
        testView = nil
        super.tearDown()
    }

    /// Demonstrates iOS 18 bug: reading accessibilityPath multiple times causes coordinates to accumulate.
    func testAccessibilityPathMutationBug() {
        print("\n" + String(repeating: "=", count: 60))
        print("iOS 18 ACCESSIBILITY PATH MUTATION BUG")
        print("iOS version: \(UIDevice.current.systemVersion)")
        print(String(repeating: "=", count: 60))
        
        let customView = BuggyAccessibilityPathView(frame: CGRect(x: 100, y: 200, width: 60, height: 40))
        customView.relativePath = UIBezierPath(roundedRect: CGRect(x: 0, y: 0, width: 60, height: 40), cornerRadius: 20)
        testView.addSubview(customView)
        window.layoutIfNeeded()
        
        let viewScreenFrame = customView.convert(customView.bounds, to: nil)
        print("Expected path origin: (\(viewScreenFrame.origin.x), \(viewScreenFrame.origin.y))\n")
        
        print("Reading accessibilityPath 5 times:")
        for i in 1...5 {
            guard let path = customView.accessibilityPath else {
                XCTFail("accessibilityPath is nil on read \(i)")
                continue
            }
            
            let ratio = viewScreenFrame.origin.x != 0 ? path.bounds.origin.x / viewScreenFrame.origin.x : 0
            let status = abs(ratio - 1.0) < 0.01 ? "✅" : "❌ BUG!"
            print("  Read \(i): origin=(\(path.bounds.origin.x), \(path.bounds.origin.y)), ratio=\(String(format: "%.1f", ratio)) \(status)")
            
            XCTAssertEqual(path.bounds.origin.x, viewScreenFrame.origin.x, accuracy: 1.0,
                "Read \(i): Path X should match. Got \(path.bounds.origin.x), expected \(viewScreenFrame.origin.x)")
        }
        print(String(repeating: "=", count: 60) + "\n")
    }
    
    /// Direct test showing convertToScreenCoordinates mutates the input path.
    func testConvertToScreenCoordinatesMutatesInput() {
        print("\n" + String(repeating: "=", count: 60))
        print("DIRECT API TEST: Does convertToScreenCoordinates mutate input?")
        print(String(repeating: "=", count: 60))
        
        let view = UIView(frame: CGRect(x: 50, y: 100, width: 60, height: 40))
        testView.addSubview(view)
        window.layoutIfNeeded()
        
        let originalPath = UIBezierPath(rect: CGRect(x: 0, y: 0, width: 60, height: 40))
        let originalBounds = originalPath.bounds
        
        print("Original path bounds: \(originalBounds)")
        print("Calling convertToScreenCoordinates 3 times on SAME path:")
        
        for i in 1...3 {
            let _ = UIAccessibility.convertToScreenCoordinates(originalPath, in: view)
            let status = originalPath.bounds != originalBounds ? "❌ MUTATED!" : "✅"
            print("  After call \(i): bounds = \(originalPath.bounds) \(status)")
        }
        
        XCTAssertEqual(originalPath.bounds, originalBounds,
            "UIAccessibility.convertToScreenCoordinates should NOT mutate its input")
        print(String(repeating: "=", count: 60) + "\n")
    }
}
