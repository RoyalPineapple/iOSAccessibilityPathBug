import XCTest
import UIKit

/// Investigation tests to understand the bug mechanism through diagnostic output.
/// These tests use XCTFail to output diagnostic information visible in Xcode.
/// They always fail by design - they're for investigation, not pass/fail validation.
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

    // MARK: - Per-CGPath Behavior Investigation

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

    // MARK: - Input vs Output Investigation

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

    // MARK: - Drift Reset Conditions

    func test_pathModificationCounterReset() {
        // What operations on a path trigger counter reset?
        let view = BuggyPathView(frame: CGRect(x: 100, y: 200, width: 60, height: 40))
        let path = UIBezierPath(roundedRect: CGRect(x: 0, y: 0, width: 60, height: 40), cornerRadius: 10)
        view.relativePath = path
        testView.addSubview(view)
        window.layoutIfNeeded()

        // Baseline: establish accumulation
        let r1 = view.accessibilityPath!.bounds.origin.x
        let r2 = view.accessibilityPath!.bounds.origin.x
        let r3 = view.accessibilityPath!.bounds.origin.x
        XCTFail("""
        === BASELINE ACCUMULATION ===
        1st: \(r1) (Expected: 100)
        2nd: \(r2) (Expected: 200)
        3rd: \(r3) (Expected: 300)
        """)

        // Test 1: Apply transform to same path object
        path.apply(CGAffineTransform(translationX: 10, y: 10))
        let afterTransform = view.accessibilityPath!.bounds.origin.x
        XCTFail("""
        === AFTER TRANSFORM (same path object) ===
        Returned X: \(afterTransform)
        Expected if counter reset: 100
        Expected if counter continued: 400
        Actual behavior: \(afterTransform == 100.0 ? "RESET" : afterTransform == 400.0 ? "CONTINUED" : "UNKNOWN")
        """)

        // Test 2: Add elements to same path object
        path.addLine(to: CGPoint(x: 100, y: 100))
        let afterAddLine = view.accessibilityPath!.bounds.origin.x
        let expectedIfReset = 100.0
        let expectedIfContinued = afterTransform == 100.0 ? 200.0 : 500.0
        XCTFail("""
        === AFTER ADD LINE (same path object) ===
        Returned X: \(afterAddLine)
        Expected if counter reset: \(expectedIfReset)
        Expected if counter continued: \(expectedIfContinued)
        Actual behavior: \(afterAddLine == expectedIfReset ? "RESET" : afterAddLine == expectedIfContinued ? "CONTINUED" : "UNKNOWN")
        """)

        // Test 3: Close path (mutation without changing identity)
        path.close()
        let afterClose = view.accessibilityPath!.bounds.origin.x
        XCTFail("""
        === AFTER CLOSE (same path object) ===
        Returned X: \(afterClose)
        Path object identity unchanged: \(path === view.relativePath)
        Does close() reset counter?
        """)
    }

    func test_pathReplacementTypes() {
        // Does the TYPE of replacement matter for counter reset?
        let view = BuggyPathView(frame: CGRect(x: 100, y: 200, width: 60, height: 40))
        testView.addSubview(view)
        window.layoutIfNeeded()

        // Start with roundedRect, establish accumulation
        view.relativePath = UIBezierPath(roundedRect: CGRect(x: 0, y: 0, width: 60, height: 40), cornerRadius: 10)
        let r1 = view.accessibilityPath!.bounds.origin.x
        let r2 = view.accessibilityPath!.bounds.origin.x
        let r3 = view.accessibilityPath!.bounds.origin.x
        XCTFail("""
        === INITIAL ACCUMULATION (roundedRect) ===
        1st: \(r1), 2nd: \(r2), 3rd: \(r3)
        """)

        // Replace with copy of same path
        view.relativePath = view.relativePath?.copy() as? UIBezierPath
        let afterCopy = view.accessibilityPath!.bounds.origin.x
        XCTFail("""
        === AFTER COPY REPLACEMENT ===
        Returned X: \(afterCopy) (Expected: 100 if reset, 400 if continued)
        Counter reset? \(afterCopy == 100.0)
        """)

        // Continue to verify copy actually reset
        let afterCopy2 = view.accessibilityPath!.bounds.origin.x
        XCTFail("""
        === 2ND READ AFTER COPY ===
        Returned X: \(afterCopy2)
        If copy reset counter: should be 200
        If copy didn't reset: would be 500
        """)

        // Replace with new path (same type, same dimensions)
        view.relativePath = UIBezierPath(roundedRect: CGRect(x: 0, y: 0, width: 60, height: 40), cornerRadius: 10)
        let afterNewSame = view.accessibilityPath!.bounds.origin.x
        XCTFail("""
        === AFTER NEW PATH (same type/dimensions) ===
        Returned X: \(afterNewSame) (Expected: 100 if reset)
        """)

        // Replace with different path type
        view.relativePath = UIBezierPath(rect: CGRect(x: 0, y: 0, width: 60, height: 40))
        let afterRect = view.accessibilityPath!.bounds.origin.x
        XCTFail("""
        === AFTER SWITCHING TO RECT (unaffected type) ===
        Returned X: \(afterRect) (Expected: 100)
        Does switching to unaffected type reset counter?
        """)

        // Switch back to affected type
        view.relativePath = UIBezierPath(roundedRect: CGRect(x: 0, y: 0, width: 60, height: 40), cornerRadius: 10)
        let afterSwitchBack = view.accessibilityPath!.bounds.origin.x
        let afterSwitchBack2 = view.accessibilityPath!.bounds.origin.x
        XCTFail("""
        === AFTER SWITCHING BACK TO ROUNDEDRECT ===
        1st read: \(afterSwitchBack)
        2nd read: \(afterSwitchBack2)
        Did rect maintain/increment counter? If yes: \(afterSwitchBack) > 100
        """)
    }

    func test_pathMutationWithoutReplacement() {
        // Does mutating stored path without reassigning reset counter?
        let view = BuggyPathView(frame: CGRect(x: 100, y: 200, width: 60, height: 40))
        let path = UIBezierPath(roundedRect: CGRect(x: 0, y: 0, width: 60, height: 40), cornerRadius: 10)
        view.relativePath = path
        testView.addSubview(view)
        window.layoutIfNeeded()

        // Establish baseline
        let r1 = view.accessibilityPath!.bounds.origin.x
        let r2 = view.accessibilityPath!.bounds.origin.x
        let r3 = view.accessibilityPath!.bounds.origin.x
        XCTFail("""
        === BASELINE ===
        Reads: \(r1), \(r2), \(r3)
        """)

        // Mutate the stored path object directly (no reassignment)
        path.apply(CGAffineTransform(scaleX: 2.0, y: 2.0))
        let pathIdentityCheck = (path === view.relativePath)
        let afterMutation = view.accessibilityPath!.bounds.origin.x
        XCTFail("""
        === AFTER MUTATING STORED PATH (no reassignment) ===
        Path identity unchanged: \(pathIdentityCheck)
        Returned X: \(afterMutation)
        Counter reset? \(afterMutation == 100.0)
        Counter continued? \(afterMutation == 400.0)
        """)

        // Try triggering property observer by reassigning same object
        let samePathReference = view.relativePath
        view.relativePath = samePathReference
        let afterReassignSame = view.accessibilityPath!.bounds.origin.x
        XCTFail("""
        === AFTER REASSIGNING SAME OBJECT ===
        Returned X: \(afterReassignSame)
        Same reference reassigned: \(samePathReference === view.relativePath)
        Does reassigning same reference reset counter?
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

    // MARK: - Alternative Workarounds (No Copy)

    func test_workaround_identityTransform() {
        // Can we reset by applying identity transform?
        let view = BuggyPathView(frame: CGRect(x: 100, y: 200, width: 60, height: 40))
        let path = UIBezierPath(roundedRect: CGRect(x: 0, y: 0, width: 60, height: 40), cornerRadius: 10)
        view.relativePath = path
        testView.addSubview(view)
        window.layoutIfNeeded()

        let expectedX: CGFloat = 100.0

        // Baseline: establish accumulation
        let r1 = view.accessibilityPath!.bounds.origin.x
        let r2 = view.accessibilityPath!.bounds.origin.x
        XCTFail("""
        === BASELINE ACCUMULATION ===
        1st: \(r1) (Expected: 100)
        2nd: \(r2) (Expected: 200)
        """)

        // Apply identity transform to "reset"
        path.apply(.identity)
        let afterIdentity1 = view.accessibilityPath!.bounds.origin.x
        let afterIdentity2 = view.accessibilityPath!.bounds.origin.x
        XCTFail("""
        === AFTER APPLYING IDENTITY TRANSFORM ===
        1st after identity: \(afterIdentity1) (Expected: 100 if reset)
        2nd after identity: \(afterIdentity2) (Expected: 100 if truly reset, 200 if accumulating)
        Original path bounds: \(path.bounds)
        Workaround viable? \(abs(afterIdentity1 - expectedX) < 0.1 && abs(afterIdentity2 - expectedX) < 0.1)
        """)
    }

    func test_workaround_cachedResult() {
        // Can we cache the first conversion and reuse it?
        let view = CachedPathView(frame: CGRect(x: 100, y: 200, width: 60, height: 40))
        let path = UIBezierPath(roundedRect: CGRect(x: 0, y: 0, width: 60, height: 40), cornerRadius: 10)
        view.relativePath = path
        testView.addSubview(view)
        window.layoutIfNeeded()

        let expectedX: CGFloat = 100.0

        let r1 = view.accessibilityPath!.bounds.origin.x
        let r2 = view.accessibilityPath!.bounds.origin.x
        let r3 = view.accessibilityPath!.bounds.origin.x
        
        XCTFail("""
        === CACHED RESULT WORKAROUND ===
        1st: \(r1) (Expected: 100)
        2nd: \(r2) (Expected: 100)
        3rd: \(r3) (Expected: 100)
        All correct? \(abs(r1 - expectedX) < 0.1 && abs(r2 - expectedX) < 0.1 && abs(r3 - expectedX) < 0.1)
        """)
    }

    func test_workaround_mutateAndRestore() {
        // Can we mutate path, convert, then restore?
        let view = BuggyPathView(frame: CGRect(x: 100, y: 200, width: 60, height: 40))
        let path = UIBezierPath(roundedRect: CGRect(x: 0, y: 0, width: 60, height: 40), cornerRadius: 10)
        view.relativePath = path
        testView.addSubview(view)
        window.layoutIfNeeded()

        let expectedX: CGFloat = 100.0
        let originalBounds = path.bounds

        // Strategy: scale up, convert, scale down
        let scaleUp = CGAffineTransform(scaleX: 2.0, y: 2.0)
        let scaleDown = CGAffineTransform(scaleX: 0.5, y: 0.5)

        // First conversion - normal
        let r1 = view.accessibilityPath!.bounds.origin.x

        // Second conversion - with mutation and restore
        path.apply(scaleUp)
        let converted2 = UIAccessibility.convertToScreenCoordinates(path, in: view)
        path.apply(scaleDown)
        let r2 = converted2.bounds.origin.x
        
        // Third conversion - normal again
        let r3 = view.accessibilityPath!.bounds.origin.x
        
        XCTFail("""
        === MUTATE AND RESTORE WORKAROUND ===
        1st (normal): \(r1) (Expected: 100)
        2nd (after mutation): \(r2) (Expected: 200)
        3rd (after restore): \(r3) (Expected: 100 if reset worked)
        Path bounds after restore: \(path.bounds)
        Original bounds: \(originalBounds)
        Bounds match? \(abs(path.bounds.origin.x - originalBounds.origin.x) < 0.1)
        """)
    }

    func test_workaround_applyAndUnapply() {
        // Simpler: apply tiny translation, convert, unapply
        let view = BuggyPathView(frame: CGRect(x: 100, y: 200, width: 60, height: 40))
        let path = UIBezierPath(roundedRect: CGRect(x: 0, y: 0, width: 60, height: 40), cornerRadius: 10)
        view.relativePath = path
        testView.addSubview(view)
        window.layoutIfNeeded()

        let expectedX: CGFloat = 100.0
        let originalBounds = path.bounds

        // Establish baseline
        let r1 = view.accessibilityPath!.bounds.origin.x
        let r2 = view.accessibilityPath!.bounds.origin.x
        
        // Apply tiny offset, convert, unapply
        let tinyOffset = CGAffineTransform(translationX: 0.001, y: 0.001)
        let reverseOffset = CGAffineTransform(translationX: -0.001, y: -0.001)
        
        path.apply(tinyOffset)
        let r3 = view.accessibilityPath!.bounds.origin.x
        path.apply(reverseOffset)
        
        let r4 = view.accessibilityPath!.bounds.origin.x
        
        XCTFail("""
        === APPLY/UNAPPLY TINY OFFSET ===
        1st: \(r1) (Expected: 100)
        2nd: \(r2) (Expected: 200)
        3rd (after tiny offset): \(r3) (Expected: 100 if reset)
        4th (after unapply): \(r4) (Expected: 100 or 200)
        Path bounds after cycle: \(path.bounds)
        Original bounds: \(originalBounds)
        Bounds restored? \(abs(path.bounds.origin.x - originalBounds.origin.x) < 0.01)
        """)
    }
}

// MARK: - Alternative Workaround Helpers

/// View that caches the first converted path and returns it
private class CachedPathView: UIView {
    var relativePath: UIBezierPath?
    private var cachedScreenPath: UIBezierPath?
    private var cachedPathIdentity: ObjectIdentifier?

    override var accessibilityPath: UIBezierPath? {
        get {
            guard let path = relativePath else { return nil }
            let currentIdentity = ObjectIdentifier(path.cgPath)
            
            // If path changed, invalidate cache
            if cachedPathIdentity != currentIdentity {
                cachedPathIdentity = currentIdentity
                cachedScreenPath = UIAccessibility.convertToScreenCoordinates(path, in: self)
            }
            
            return cachedScreenPath
        }
        set { fatalError("use relativePath instead") }
    }
}
