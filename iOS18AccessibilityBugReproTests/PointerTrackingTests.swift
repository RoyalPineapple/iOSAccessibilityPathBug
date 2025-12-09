import XCTest
import UIKit

/// Track object pointers to understand the mutation
final class PointerTrackingTests: XCTestCase {
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
    
    /// Track UIBezierPath and CGPath pointers through multiple calls
    func test_trackPointers() {
        let path = UIBezierPath()
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: 10, y: 10))
        
        let view = UIView(frame: CGRect(x: 100, y: 200, width: 60, height: 40))
        testView.addSubview(view)
        window.layoutIfNeeded()
        
        // Input UIBezierPath pointer
        let inputPathPtr = Unmanaged.passUnretained(path).toOpaque()
        
        // Input CGPath pointer before
        let inputCGPathBefore = path.cgPath
        let inputCGPathPtrBefore = Unmanaged.passUnretained(inputCGPathBefore).toOpaque()
        
        // Call API
        let output = UIAccessibility.convertToScreenCoordinates(path, in: view)
        
        // Output UIBezierPath pointer
        let outputPathPtr = Unmanaged.passUnretained(output).toOpaque()
        
        // Input CGPath pointer after
        let inputCGPathAfter = path.cgPath
        let inputCGPathPtrAfter = Unmanaged.passUnretained(inputCGPathAfter).toOpaque()
        
        // Output CGPath pointer
        let outputCGPath = output.cgPath
        let outputCGPathPtr = Unmanaged.passUnretained(outputCGPath).toOpaque()
        
        // Report findings
        let sameUIBezierPath = inputPathPtr == outputPathPtr
        let sameCGPathBeforeAfter = inputCGPathPtrBefore == inputCGPathPtrAfter
        let inputOutputShareCGPath = inputCGPathPtrAfter == outputCGPathPtr
        
        print("=== POINTER ANALYSIS ===")
        print("Input UIBezierPath ptr:  \(inputPathPtr)")
        print("Output UIBezierPath ptr: \(outputPathPtr)")
        print("Same UIBezierPath? \(sameUIBezierPath)")
        print("")
        print("Input CGPath BEFORE:  \(inputCGPathPtrBefore)")
        print("Input CGPath AFTER:   \(inputCGPathPtrAfter)")
        print("Same CGPath in input? \(sameCGPathBeforeAfter)")
        print("")
        print("Output CGPath:        \(outputCGPathPtr)")
        print("Input & Output share CGPath? \(inputOutputShareCGPath)")
        
        // Assertions to document behavior
        if sameUIBezierPath {
            XCTFail("BUG: Output is SAME UIBezierPath as input!")
        } else {
            XCTAssertTrue(true, "Output is different UIBezierPath")
        }
        
        if !sameCGPathBeforeAfter {
            // CGPath was replaced in the input - interesting!
            XCTAssertTrue(true, "Input's CGPath was replaced")
        }
        
        if inputOutputShareCGPath {
            XCTFail("BUG: Input and Output share the same CGPath!")
        }
    }
    
    /// Check bounds at each stage
    func test_boundsAtEachStage() {
        let path = UIBezierPath()
        path.move(to: CGPoint(x: 5, y: 10))
        path.addLine(to: CGPoint(x: 15, y: 20))
        
        let view = UIView(frame: CGRect(x: 100, y: 200, width: 60, height: 40))
        testView.addSubview(view)
        window.layoutIfNeeded()
        
        let screenOffset = view.convert(CGPoint.zero, to: nil)
        
        // Record input bounds before
        let inputBoundsBefore = path.bounds
        let inputCGPathBoundsBefore = path.cgPath.boundingBox
        
        // Call API
        let output = UIAccessibility.convertToScreenCoordinates(path, in: view)
        
        // Record all bounds after
        let inputBoundsAfter = path.bounds
        let inputCGPathBoundsAfter = path.cgPath.boundingBox
        let outputBounds = output.bounds
        let outputCGPathBounds = output.cgPath.boundingBox
        
        print("=== BOUNDS ANALYSIS ===")
        print("Screen offset: \(screenOffset)")
        print("")
        print("Input UIBezierPath.bounds BEFORE: \(inputBoundsBefore)")
        print("Input CGPath.boundingBox BEFORE:  \(inputCGPathBoundsBefore)")
        print("")
        print("Input UIBezierPath.bounds AFTER:  \(inputBoundsAfter)")
        print("Input CGPath.boundingBox AFTER:   \(inputCGPathBoundsAfter)")
        print("")
        print("Output UIBezierPath.bounds:       \(outputBounds)")
        print("Output CGPath.boundingBox:        \(outputCGPathBounds)")
        
        // Check relationships
        let inputWasMutated = inputBoundsAfter != inputBoundsBefore
        let inputMatchesOutput = inputBoundsAfter == outputBounds
        
        print("")
        print("Input was mutated? \(inputWasMutated)")
        print("Input matches output? \(inputMatchesOutput)")
        
        // Expected: input + offset = output
        let expectedOutputX = inputBoundsBefore.origin.x + screenOffset.x
        let expectedOutputY = inputBoundsBefore.origin.y + screenOffset.y
        
        XCTAssertEqual(outputBounds.origin.x, expectedOutputX, accuracy: 0.1,
            "Output X should be input + offset")
        XCTAssertEqual(outputBounds.origin.y, expectedOutputY, accuracy: 0.1,
            "Output Y should be input + offset")
        
        // If input was mutated, it should equal output
        if inputWasMutated {
            XCTAssertEqual(inputBoundsAfter.origin.x, outputBounds.origin.x, accuracy: 0.1,
                "If input mutated, should equal output")
        }
    }
    
    /// The key question: does the output share storage with the input?
    func test_sharedStorage() {
        let path = UIBezierPath()
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: 10, y: 10))
        
        let view = UIView(frame: CGRect(x: 100, y: 200, width: 60, height: 40))
        testView.addSubview(view)
        window.layoutIfNeeded()
        
        let output = UIAccessibility.convertToScreenCoordinates(path, in: view)
        
        // Now modify output and see if input changes
        let inputBoundsBefore = path.bounds
        
        // Try to modify output
        output.apply(CGAffineTransform(translationX: 1000, y: 1000))
        
        let inputBoundsAfter = path.bounds
        let outputBoundsAfter = output.bounds
        
        let inputChangedWhenOutputModified = inputBoundsBefore != inputBoundsAfter
        
        print("=== SHARED STORAGE TEST ===")
        print("Input bounds before modifying output: \(inputBoundsBefore)")
        print("Input bounds after modifying output:  \(inputBoundsAfter)")
        print("Output bounds after modification:     \(outputBoundsAfter)")
        print("Did input change when output modified? \(inputChangedWhenOutputModified)")
        
        if inputChangedWhenOutputModified {
            XCTFail("SHARED STORAGE: Modifying output also modified input!")
        } else {
            XCTAssertTrue(true, "Input and output have separate storage")
        }
    }
}
