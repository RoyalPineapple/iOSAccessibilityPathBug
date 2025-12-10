import XCTest
import UIKit

/// Deep investigation into the mechanism of the iOS 18+ bug.
/// These tests probe internal state, accumulation patterns, and scope of the mutation.
final class BugMechanismInvestigation: XCTestCase {
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

    func test_freshPathEachTime() {
        // Does using a fresh path each time prevent accumulation?
        let view = BuggyPathView(frame: CGRect(x: 100, y: 200, width: 60, height: 40))
        testView.addSubview(view)
        window.layoutIfNeeded()

        let expectedX: CGFloat = 100.0

        // 1st read with fresh path
        view.relativePath = UIBezierPath(roundedRect: CGRect(x: 0, y: 0, width: 60, height: 40), cornerRadius: 10)
        let first = view.accessibilityPath!.bounds.origin.x
        XCTFail("1st read (fresh path): \(first), Expected: \(expectedX)")

        // 2nd read with fresh path
        view.relativePath = UIBezierPath(roundedRect: CGRect(x: 0, y: 0, width: 60, height: 40), cornerRadius: 10)
        let second = view.accessibilityPath!.bounds.origin.x
        XCTFail("2nd read (fresh path): \(second), Expected: \(expectedX)")

        // 3rd read with fresh path
        view.relativePath = UIBezierPath(roundedRect: CGRect(x: 0, y: 0, width: 60, height: 40), cornerRadius: 10)
        let third = view.accessibilityPath!.bounds.origin.x
        XCTFail("3rd read (fresh path): \(third), Expected: \(expectedX)")
    }

    func test_freshViewEachTime() {
        // Does creating a fresh view each time prevent accumulation?
        let expectedX: CGFloat = 100.0

        // 1st view
        let view1 = BuggyPathView(frame: CGRect(x: 100, y: 200, width: 60, height: 40))
        view1.relativePath = UIBezierPath(roundedRect: CGRect(x: 0, y: 0, width: 60, height: 40), cornerRadius: 10)
        testView.addSubview(view1)
        window.layoutIfNeeded()
        let first = view1.accessibilityPath!.bounds.origin.x
        view1.removeFromSuperview()
        XCTFail("1st view: \(first), Expected: \(expectedX)")

        // 2nd view
        let view2 = BuggyPathView(frame: CGRect(x: 100, y: 200, width: 60, height: 40))
        view2.relativePath = UIBezierPath(roundedRect: CGRect(x: 0, y: 0, width: 60, height: 40), cornerRadius: 10)
        testView.addSubview(view2)
        window.layoutIfNeeded()
        let second = view2.accessibilityPath!.bounds.origin.x
        view2.removeFromSuperview()
        XCTFail("2nd view: \(second), Expected: \(expectedX)")

        // 3rd view
        let view3 = BuggyPathView(frame: CGRect(x: 100, y: 200, width: 60, height: 40))
        view3.relativePath = UIBezierPath(roundedRect: CGRect(x: 0, y: 0, width: 60, height: 40), cornerRadius: 10)
        testView.addSubview(view3)
        window.layoutIfNeeded()
        let third = view3.accessibilityPath!.bounds.origin.x
        view3.removeFromSuperview()
        XCTFail("3rd view: \(third), Expected: \(expectedX)")
    }

    func test_multipleViews() {
        // Do multiple views accumulate independently or share state?
        let view1 = BuggyPathView(frame: CGRect(x: 100, y: 200, width: 60, height: 40))
        view1.relativePath = UIBezierPath(roundedRect: CGRect(x: 0, y: 0, width: 60, height: 40), cornerRadius: 10)

        let view2 = BuggyPathView(frame: CGRect(x: 300, y: 400, width: 60, height: 40))
        view2.relativePath = UIBezierPath(roundedRect: CGRect(x: 0, y: 0, width: 60, height: 40), cornerRadius: 10)

        testView.addSubview(view1)
        testView.addSubview(view2)
        window.layoutIfNeeded()

        let v1_r1 = view1.accessibilityPath!.bounds.origin.x
        let v2_r1 = view2.accessibilityPath!.bounds.origin.x
        let v1_r2 = view1.accessibilityPath!.bounds.origin.x
        let v2_r2 = view2.accessibilityPath!.bounds.origin.x
        let v1_r3 = view1.accessibilityPath!.bounds.origin.x
        let v2_r3 = view2.accessibilityPath!.bounds.origin.x

        XCTFail("""
        View1: 1st=\(v1_r1), 2nd=\(v1_r2), 3rd=\(v1_r3) (Expected: 100)
        View2: 1st=\(v2_r1), 2nd=\(v2_r2), 3rd=\(v2_r3) (Expected: 300)
        """)
    }

    func test_viewStateAccumulation() {
        // Does the view have internal state that accumulates?
        let view = BuggyPathView(frame: CGRect(x: 100, y: 200, width: 60, height: 40))
        let path = UIBezierPath(roundedRect: CGRect(x: 0, y: 0, width: 60, height: 40), cornerRadius: 10)
        view.relativePath = path
        testView.addSubview(view)
        window.layoutIfNeeded()

        // Read multiple times
        _ = view.accessibilityPath
        _ = view.accessibilityPath
        let afterReads = view.accessibilityPath!.bounds.origin.x

        // Now set a different path
        view.relativePath = UIBezierPath(roundedRect: CGRect(x: 0, y: 0, width: 60, height: 40), cornerRadius: 10)
        let afterNewPath = view.accessibilityPath!.bounds.origin.x

        // Move the view
        view.frame = CGRect(x: 200, y: 300, width: 60, height: 40)
        window.layoutIfNeeded()
        let afterMove = view.accessibilityPath!.bounds.origin.x

        XCTFail("""
        After 3 reads: \(afterReads) (Expected: 300)
        After setting new path: \(afterNewPath) (Expected: 100 if state reset, 400 if not)
        After moving view: \(afterMove) (Expected: 200)
        """)
    }

    func test_detailedMutationDiagnostics() {
        // Comprehensive logging to understand what gets mutated
        let view = BuggyPathView(frame: CGRect(x: 100, y: 200, width: 60, height: 40))
        let path = UIBezierPath(roundedRect: CGRect(x: 0, y: 0, width: 60, height: 40), cornerRadius: 10)
        view.relativePath = path
        testView.addSubview(view)
        window.layoutIfNeeded()

        let initialBounds = path.bounds
        let initialCGPath = path.cgPath
        let expectedX = view.convert(view.bounds, to: nil).origin.x + path.bounds.origin.x

        XCTFail("""
        === INITIAL STATE ===
        Input path bounds: \(path.bounds)
        Input CGPath pointer: \(Unmanaged.passUnretained(path.cgPath).toOpaque())
        Expected X: \(expectedX)
        """)

        let firstPath = view.accessibilityPath!
        let first = firstPath.bounds.origin.x
        XCTFail("""
        === AFTER 1ST READ ===
        Returned path bounds: \(firstPath.bounds)
        Returned CGPath pointer: \(Unmanaged.passUnretained(firstPath.cgPath).toOpaque())
        Input path bounds: \(path.bounds)
        Input CGPath pointer: \(Unmanaged.passUnretained(path.cgPath).toOpaque())
        CGPath same? \(initialCGPath == path.cgPath)
        Returned X: \(first), Expected: \(expectedX)
        """)

        let secondPath = view.accessibilityPath!
        let second = secondPath.bounds.origin.x
        XCTFail("""
        === AFTER 2ND READ ===
        Returned path bounds: \(secondPath.bounds)
        Returned CGPath pointer: \(Unmanaged.passUnretained(secondPath.cgPath).toOpaque())
        Input path bounds: \(path.bounds)
        Input CGPath pointer: \(Unmanaged.passUnretained(path.cgPath).toOpaque())
        CGPath same? \(initialCGPath == path.cgPath)
        Returned X: \(second), Expected: \(expectedX)
        """)

        let thirdPath = view.accessibilityPath!
        let third = thirdPath.bounds.origin.x
        XCTFail("""
        === AFTER 3RD READ ===
        Returned path bounds: \(thirdPath.bounds)
        Returned CGPath pointer: \(Unmanaged.passUnretained(thirdPath.cgPath).toOpaque())
        Input path bounds: \(path.bounds)
        Input CGPath pointer: \(Unmanaged.passUnretained(path.cgPath).toOpaque())
        CGPath same? \(initialCGPath == path.cgPath)
        Returned X: \(third), Expected: \(expectedX)
        """)

        XCTFail("""
        === SUMMARY ===
        Input UIBezierPath unchanged: \(path === view.relativePath)
        Input bounds unchanged: \(initialBounds == path.bounds)
        Input CGPath pointer unchanged: \(initialCGPath == path.cgPath)
        """)
    }

    func test_returnedPathIdentity() {
        // Do we get the same path object back, or a new one each time?
        let view = BuggyPathView(frame: CGRect(x: 100, y: 200, width: 60, height: 40))
        let path = UIBezierPath(roundedRect: CGRect(x: 0, y: 0, width: 60, height: 40), cornerRadius: 10)
        view.relativePath = path
        testView.addSubview(view)
        window.layoutIfNeeded()

        let first = view.accessibilityPath!
        let second = view.accessibilityPath!
        let third = view.accessibilityPath!

        XCTFail("""
        === RETURNED PATH IDENTITY ===
        1st and 2nd same object? \(first === second)
        2nd and 3rd same object? \(second === third)
        1st and input same object? \(first === path)
        1st bounds: \(first.bounds)
        2nd bounds: \(second.bounds)
        3rd bounds: \(third.bounds)
        """)
    }

    func test_heldPathMutation() {
        // If we hold onto a returned path, does it change?
        let view = BuggyPathView(frame: CGRect(x: 100, y: 200, width: 60, height: 40))
        let path = UIBezierPath(roundedRect: CGRect(x: 0, y: 0, width: 60, height: 40), cornerRadius: 10)
        view.relativePath = path
        testView.addSubview(view)
        window.layoutIfNeeded()

        let heldPath = view.accessibilityPath!
        let heldBounds = heldPath.bounds

        XCTFail("""
        === HELD PATH MUTATION ===
        Held path initial bounds: \(heldBounds)
        """)

        _ = view.accessibilityPath  // trigger another read
        XCTFail("""
        After 2nd read, held path bounds: \(heldPath.bounds)
        Held path mutated? \(heldPath.bounds != heldBounds)
        """)

        _ = view.accessibilityPath  // trigger another read
        XCTFail("""
        After 3rd read, held path bounds: \(heldPath.bounds)
        Held path mutated? \(heldPath.bounds != heldBounds)
        """)
    }

    func test_directConversionCall() {
        // What happens when we call convertToScreenCoordinates directly?
        let view = BuggyPathView(frame: CGRect(x: 100, y: 200, width: 60, height: 40))
        testView.addSubview(view)
        window.layoutIfNeeded()

        let path = UIBezierPath(roundedRect: CGRect(x: 0, y: 0, width: 60, height: 40), cornerRadius: 10)
        let initialBounds = path.bounds

        XCTFail("""
        === DIRECT CONVERSION ===
        Initial path bounds: \(initialBounds)
        """)

        let converted1 = UIAccessibility.convertToScreenCoordinates(path, in: view)
        XCTFail("""
        After 1st conversion:
          Input path bounds: \(path.bounds)
          Returned path bounds: \(converted1.bounds)
          Same object? \(path === converted1)
        """)

        let converted2 = UIAccessibility.convertToScreenCoordinates(path, in: view)
        XCTFail("""
        After 2nd conversion:
          Input path bounds: \(path.bounds)
          Returned path bounds: \(converted2.bounds)
          Same object? \(path === converted2)
        """)

        let converted3 = UIAccessibility.convertToScreenCoordinates(path, in: view)
        XCTFail("""
        After 3rd conversion:
          Input path bounds: \(path.bounds)
          Returned path bounds: \(converted3.bounds)
          Same object? \(path === converted3)
        """)
    }
}

// MARK: - Test Helpers

/// View that implements accessibilityPath using the documented pattern
private class BuggyPathView: UIView {
    var relativePath: UIBezierPath?

    override var accessibilityPath: UIBezierPath? {
        get {
            guard let path = relativePath else { return nil }
            return UIAccessibility.convertToScreenCoordinates(path, in: self)
        }
        set { fatalError("use relativePath instead") }
    }
}
