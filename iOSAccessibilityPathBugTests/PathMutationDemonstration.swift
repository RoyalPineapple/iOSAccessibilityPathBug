import XCTest
import UIKit

/// Demonstrates the iOS 18+ bug where UIAccessibility.convertToScreenCoordinates
/// mutates its input UIBezierPath, causing output coordinates to drift on repeated reads.
///
/// Expected: Output path coordinates remain stable across multiple reads
/// Actual (iOS 18+): Output coordinates accumulate, drifting further each time
final class PathMutationDemonstration: XCTestCase {
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

    // MARK: - Core Bug Demonstration

    func test_roundedRectPath_coordinatesDriftOnRepeatedReads() {
        // Canonical example from README: roundedRect path causes coordinate drift
        let view = AccessibilityPathView(frame: CGRect(x: 100, y: 200, width: 60, height: 40))
        let path = UIBezierPath(roundedRect: CGRect(x: 0, y: 0, width: 60, height: 40), cornerRadius: 10)
        view.relativePath = path
        testView.addSubview(view)
        window.layoutIfNeeded()

        let expectedX = view.convert(view.bounds, to: nil).origin.x + path.bounds.origin.x

        // Expected: All reads return the same coordinates
        // Actual (iOS 18+): Coordinates drift, test FAILS
        let first = view.accessibilityPath!.bounds.origin.x
        XCTAssertEqual(first, expectedX, "1st read should return correct coordinates")

        let second = view.accessibilityPath!.bounds.origin.x
        XCTAssertEqual(second, expectedX, "2nd read should return same coordinates (FAILS on iOS 18+)")

        let third = view.accessibilityPath!.bounds.origin.x
        XCTAssertEqual(third, expectedX, "3rd read should return same coordinates (FAILS on iOS 18+)")
    }

    // MARK: - Path Type Verification
    
    func test_cgPathWithQuadCurve_coordinatesDriftOnRepeatedReads() {
        // CGPath with explicit quadCurve elements - affected by bug
        let view = AccessibilityPathView(frame: CGRect(x: 100, y: 200, width: 60, height: 40))
        let cgPath = CGMutablePath()
        cgPath.move(to: .zero)
        cgPath.addQuadCurve(to: CGPoint(x: 60, y: 40), control: CGPoint(x: 15, y: 30))
        let path = UIBezierPath(cgPath: cgPath)
        view.relativePath = path
        testView.addSubview(view)
        window.layoutIfNeeded()

        let expectedX = view.convert(view.bounds, to: nil).origin.x + path.bounds.origin.x

        let first = view.accessibilityPath!.bounds.origin.x
        XCTAssertEqual(first, expectedX, "1st read should return correct coordinates")

        let second = view.accessibilityPath!.bounds.origin.x
        XCTAssertEqual(second, expectedX, "2nd read should return same coordinates (FAILS on iOS 18+)")

        let third = view.accessibilityPath!.bounds.origin.x
        XCTAssertEqual(third, expectedX, "3rd read should return same coordinates (FAILS on iOS 18+)")
    }

    func test_cgPathWithLines_coordinatesDriftOnRepeatedReads() {
        // CGPath with explicit line elements - affected by bug
        let view = AccessibilityPathView(frame: CGRect(x: 100, y: 200, width: 60, height: 40))
        let cgPath = CGMutablePath()
        cgPath.move(to: CGPoint(x: 0, y: 40))
        cgPath.addLine(to: CGPoint(x: 20, y: 15))
        cgPath.addLine(to: CGPoint(x: 40, y: 25))
        cgPath.addLine(to: CGPoint(x: 60, y: 0))
        let path = UIBezierPath(cgPath: cgPath)
        view.relativePath = path
        testView.addSubview(view)
        window.layoutIfNeeded()

        let expectedX = view.convert(view.bounds, to: nil).origin.x + path.bounds.origin.x

        let first = view.accessibilityPath!.bounds.origin.x
        XCTAssertEqual(first, expectedX, "1st read should return correct coordinates")

        let second = view.accessibilityPath!.bounds.origin.x
        XCTAssertEqual(second, expectedX, "2nd read should return same coordinates (FAILS on iOS 18+)")

        let third = view.accessibilityPath!.bounds.origin.x
        XCTAssertEqual(third, expectedX, "3rd read should return same coordinates (FAILS on iOS 18+)")
    }

    func test_rectPath_coordinatesStableOnRepeatedReads() {
        // rect uses optimized representation - not affected by bug
        let view = AccessibilityPathView(frame: CGRect(x: 100, y: 200, width: 60, height: 40))
        let path = UIBezierPath(rect: CGRect(x: 0, y: 0, width: 60, height: 40))
        view.relativePath = path
        testView.addSubview(view)
        window.layoutIfNeeded()

        let expectedX = view.convert(view.bounds, to: nil).origin.x + path.bounds.origin.x

        XCTAssertEqual(view.accessibilityPath!.bounds.origin.x, expectedX, "1st read")
        XCTAssertEqual(view.accessibilityPath!.bounds.origin.x, expectedX, "2nd read")
        XCTAssertEqual(view.accessibilityPath!.bounds.origin.x, expectedX, "3rd read")
    }

    func test_ovalPath_coordinatesStableOnRepeatedReads() {
        // ovalIn uses optimized representation - not affected by bug
        let view = AccessibilityPathView(frame: CGRect(x: 100, y: 200, width: 60, height: 40))
        let path = UIBezierPath(ovalIn: CGRect(x: 0, y: 0, width: 60, height: 40))
        view.relativePath = path
        testView.addSubview(view)
        window.layoutIfNeeded()

        let expectedX = view.convert(view.bounds, to: nil).origin.x + path.bounds.origin.x

        XCTAssertEqual(view.accessibilityPath!.bounds.origin.x, expectedX, "1st read")
        XCTAssertEqual(view.accessibilityPath!.bounds.origin.x, expectedX, "2nd read")
        XCTAssertEqual(view.accessibilityPath!.bounds.origin.x, expectedX, "3rd read")
    }

    func test_arcCenterPath_coordinatesStableOnRepeatedReads() {
        // arcCenter uses optimized representation - not affected by bug
        let view = AccessibilityPathView(frame: CGRect(x: 100, y: 200, width: 60, height: 40))
        let path = UIBezierPath(arcCenter: CGPoint(x: 30, y: 20), radius: 20,
                                startAngle: 0, endAngle: 1.57, clockwise: true)
        view.relativePath = path
        testView.addSubview(view)
        window.layoutIfNeeded()

        let expectedX = view.convert(view.bounds, to: nil).origin.x + path.bounds.origin.x

        XCTAssertEqual(view.accessibilityPath!.bounds.origin.x, expectedX, "1st read")
        XCTAssertEqual(view.accessibilityPath!.bounds.origin.x, expectedX, "2nd read")
        XCTAssertEqual(view.accessibilityPath!.bounds.origin.x, expectedX, "3rd read")
    }


    // MARK: - Other Trigger Conditions

    func test_detachedView_noCoordinateDrift() {
        // Bug only occurs when view is in a visible window hierarchy
        let view = AccessibilityPathView(frame: CGRect(x: 100, y: 200, width: 60, height: 40))
        let path = UIBezierPath(roundedRect: CGRect(x: 0, y: 0, width: 60, height: 40), cornerRadius: 10)
        view.relativePath = path
        // Note: view NOT added to window

        let original = path.bounds

        _ = view.accessibilityPath
        _ = view.accessibilityPath
        _ = view.accessibilityPath

        XCTAssertEqual(path.bounds, original, "Detached view: no mutation occurs")
    }

    // MARK: - Workaround Verification

    func test_workaround_copyPath_coordinatesStable() {
        // Workaround: copying the path prevents mutation and drift
        let view = FixedAccessibilityPathView(frame: CGRect(x: 100, y: 200, width: 60, height: 40))
        let path = UIBezierPath(roundedRect: CGRect(x: 0, y: 0, width: 60, height: 40), cornerRadius: 10)
        view.relativePath = path
        testView.addSubview(view)
        window.layoutIfNeeded()

        let expectedX = view.convert(view.bounds, to: nil).origin.x + path.bounds.origin.x

        XCTAssertEqual(view.accessibilityPath!.bounds.origin.x, expectedX, "1st read")
        XCTAssertEqual(view.accessibilityPath!.bounds.origin.x, expectedX, "2nd read")
        XCTAssertEqual(view.accessibilityPath!.bounds.origin.x, expectedX, "3rd read")
        XCTAssertEqual(path.bounds.origin.x, 0, accuracy: 0.1, "Original path unchanged")
    }
}

// MARK: - Test Helpers

/// View that implements accessibilityPath using the documented pattern
private class AccessibilityPathView: UIView {
    var relativePath: UIBezierPath?

    override var accessibilityPath: UIBezierPath? {
        get {
            guard let path = relativePath else { return nil }
            return UIAccessibility.convertToScreenCoordinates(path, in: self)
        }
        set { super.accessibilityPath = newValue }
    }
}

/// View that implements the workaround by copying the path
private class FixedAccessibilityPathView: UIView {
    var relativePath: UIBezierPath?

    override var accessibilityPath: UIBezierPath? {
        get {
            guard let path = relativePath?.copy() as? UIBezierPath else { return nil }
            return UIAccessibility.convertToScreenCoordinates(path, in: self)
        }
        set { super.accessibilityPath = newValue }
    }
}
