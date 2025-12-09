import XCTest
import UIKit

/// Track how many times accessibilityPath getter is called
private class TrackedPathView: UIView {
    var relativePath: UIBezierPath?
    var getterCallCount = 0
    var lastReturnedBounds: CGRect?

    override var accessibilityPath: UIBezierPath? {
        get {
            getterCallCount += 1
            guard let path = relativePath else { return nil }
            let result = UIAccessibility.convertToScreenCoordinates(path, in: self)
            lastReturnedBounds = result.bounds
            return result
        }
        set { super.accessibilityPath = newValue }
    }
}

/// Tests to see if the accessibility system calls the getter multiple times
final class AccessibilitySystemTests: XCTestCase {
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

    /// Count how many times our getter is called when we access it once
    func test_singleAccessCallCount() {
        let path = UIBezierPath()
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: 10, y: 10))
        
        let view = TrackedPathView(frame: CGRect(x: 100, y: 200, width: 60, height: 40))
        view.relativePath = path
        view.isAccessibilityElement = true
        testView.addSubview(view)
        window.layoutIfNeeded()
        
        let initialCount = view.getterCallCount
        
        // Access once
        _ = view.accessibilityPath
        
        let callsForOneAccess = view.getterCallCount - initialCount
        
        // Report
        XCTAssertEqual(callsForOneAccess, 1,
            "Expected 1 call per access, got \(callsForOneAccess)")
    }
    
    /// Direct test: what does the API actually return vs what it does to input?
    func test_whatDoesAPIActuallyDo() {
        let path = UIBezierPath()
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: 10, y: 10))
        let originalBounds = path.bounds
        
        let view = UIView(frame: CGRect(x: 100, y: 200, width: 60, height: 40))
        testView.addSubview(view)
        window.layoutIfNeeded()
        
        let screenOffset = view.convert(CGPoint.zero, to: nil)
        
        // Call API directly
        let output1 = UIAccessibility.convertToScreenCoordinates(path, in: view)
        let inputAfter1 = path.bounds
        
        // What did we get?
        let outputOffset1 = CGPoint(
            x: output1.bounds.origin.x - originalBounds.origin.x,
            y: output1.bounds.origin.y - originalBounds.origin.y
        )
        let inputOffset1 = CGPoint(
            x: inputAfter1.origin.x - originalBounds.origin.x,
            y: inputAfter1.origin.y - originalBounds.origin.y
        )
        
        XCTAssertEqual(outputOffset1.x, screenOffset.x, accuracy: 0.1,
            "Output should be offset by screen offset")
        
        // Was input mutated?
        if inputOffset1.x > 0.1 || inputOffset1.y > 0.1 {
            XCTFail("INPUT WAS MUTATED by API! Offset: \(inputOffset1)")
        }
        
        // Second call
        let output2 = UIAccessibility.convertToScreenCoordinates(path, in: view)
        let inputAfter2 = path.bounds
        
        // Check if second output is different (accumulation)
        let outputsDifferent = output1.bounds != output2.bounds
        if outputsDifferent {
            let delta = CGPoint(
                x: output2.bounds.origin.x - output1.bounds.origin.x,
                y: output2.bounds.origin.y - output1.bounds.origin.y
            )
            XCTFail("OUTPUTS DIFFER! Delta: \(delta)")
        }
    }
    
    /// The real test: does the input get mutated when view is visible?
    func test_inputMutationWithVisibleView() {
        let path = UIBezierPath()
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: 10, y: 10))
        
        let view = TrackedPathView(frame: CGRect(x: 100, y: 200, width: 60, height: 40))
        view.relativePath = path
        view.isAccessibilityElement = true
        testView.addSubview(view)
        window.layoutIfNeeded()
        
        // Record initial
        let originalBounds = path.bounds
        
        // Access via property multiple times
        for i in 1...3 {
            _ = view.accessibilityPath
            let currentBounds = path.bounds
            
            if currentBounds != originalBounds {
                let delta = CGPoint(
                    x: currentBounds.origin.x - originalBounds.origin.x,
                    y: currentBounds.origin.y - originalBounds.origin.y
                )
                XCTFail("Read \(i): INPUT PATH MUTATED! Delta: \(delta), Getter calls: \(view.getterCallCount)")
            }
        }
    }
}
