import XCTest
import UIKit

private class PathView: UIView {
    var relativePath: UIBezierPath?
    var readCount = 0

    override var accessibilityPath: UIBezierPath? {
        get {
            guard let path = relativePath else { return nil }
            readCount += 1
            return UIAccessibility.convertToScreenCoordinates(path, in: self)
        }
        set { super.accessibilityPath = newValue }
    }
}

/// Debug tests to understand exactly what's happening
final class DebugMutationTests: XCTestCase {
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

    /// Track exactly what happens on each read
    func test_trackEachRead() {
        let path = UIBezierPath()
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: 10, y: 10))
        
        let view = PathView(frame: CGRect(x: 100, y: 200, width: 60, height: 40))
        view.relativePath = path
        testView.addSubview(view)
        window.layoutIfNeeded()
        
        let screenOffset = view.convert(CGPoint.zero, to: nil)
        
        // Track state at each step
        struct State {
            let readNum: Int
            let inputBoundsBefore: CGRect
            let outputBounds: CGRect
            let inputBoundsAfter: CGRect
        }
        
        var states: [State] = []
        
        for i in 1...3 {
            let inputBefore = path.bounds
            let output = view.accessibilityPath!
            let inputAfter = path.bounds
            
            states.append(State(
                readNum: i,
                inputBoundsBefore: inputBefore,
                outputBounds: output.bounds,
                inputBoundsAfter: inputAfter
            ))
        }
        
        // Report findings with assertions
        for state in states {
            // Was input mutated by this read?
            let inputMutated = state.inputBoundsBefore != state.inputBoundsAfter
            
            if inputMutated {
                let deltaX = state.inputBoundsAfter.origin.x - state.inputBoundsBefore.origin.x
                let deltaY = state.inputBoundsAfter.origin.y - state.inputBoundsBefore.origin.y
                XCTFail("Read \(state.readNum): INPUT WAS MUTATED by (\(deltaX), \(deltaY))")
            }
            
            // Does output match expected?
            let expectedX = CGFloat(state.readNum) * screenOffset.x
            let expectedY = CGFloat(state.readNum) * screenOffset.y
            
            XCTAssertEqual(state.outputBounds.origin.x, expectedX, accuracy: 0.1,
                "Read \(state.readNum): output X should be \(expectedX), got \(state.outputBounds.origin.x)")
        }
    }
    
    /// Check if the output matches the (potentially mutated) input
    func test_outputMatchesMutatedInput() {
        let path = UIBezierPath()
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: 10, y: 10))
        
        let view = PathView(frame: CGRect(x: 100, y: 200, width: 60, height: 40))
        view.relativePath = path
        testView.addSubview(view)
        window.layoutIfNeeded()
        
        // Read and immediately check both
        let output1 = view.accessibilityPath!
        XCTAssertEqual(output1.bounds.origin.x, path.bounds.origin.x, accuracy: 0.1,
            "After read 1: output.bounds.origin.x == path.bounds.origin.x? output=\(output1.bounds.origin.x), path=\(path.bounds.origin.x)")
        
        let output2 = view.accessibilityPath!
        XCTAssertEqual(output2.bounds.origin.x, path.bounds.origin.x, accuracy: 0.1,
            "After read 2: output.bounds.origin.x == path.bounds.origin.x? output=\(output2.bounds.origin.x), path=\(path.bounds.origin.x)")
    }
    
    /// Direct API call test (bypassing accessibilityPath getter)
    func test_directAPICall() {
        let path = UIBezierPath()
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: 10, y: 10))
        let originalBounds = path.bounds
        
        let view = UIView(frame: CGRect(x: 100, y: 200, width: 60, height: 40))
        testView.addSubview(view)
        window.layoutIfNeeded()
        
        // Direct API calls
        let output1 = UIAccessibility.convertToScreenCoordinates(path, in: view)
        let afterFirst = path.bounds
        
        let output2 = UIAccessibility.convertToScreenCoordinates(path, in: view)
        let afterSecond = path.bounds
        
        // Check if direct calls mutate
        let mutatedAfterFirst = afterFirst != originalBounds
        let mutatedAfterSecond = afterSecond != afterFirst
        
        if mutatedAfterFirst {
            XCTFail("DIRECT CALL mutated input! Before: \(originalBounds), After: \(afterFirst)")
        } else {
            XCTAssertEqual(afterFirst, originalBounds, "Direct call should not mutate input")
        }
        
        if mutatedAfterSecond {
            XCTFail("SECOND DIRECT CALL mutated input! Before: \(afterFirst), After: \(afterSecond)")
        }
    }
}
