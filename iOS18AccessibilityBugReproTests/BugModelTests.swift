import XCTest
import UIKit

/// A single comprehensive test to model the bug behavior
final class BugModelTests: XCTestCase {
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

    /// Model: The API mutates input in-place AND returns it (same object? or copy that shares CGPath?)
    func test_bugModel_directAPI() {
        let path = UIBezierPath()
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: 10, y: 10))
        
        let view = UIView(frame: CGRect(x: 100, y: 200, width: 60, height: 40))
        testView.addSubview(view)
        window.layoutIfNeeded()
        
        let screenOffset = view.convert(CGPoint.zero, to: nil) // (100, 200)
        
        // Store original input bounds
        let original = path.bounds
        
        // Call 1
        let out1 = UIAccessibility.convertToScreenCoordinates(path, in: view)
        let inputAfter1 = path.bounds
        
        // Call 2
        let out2 = UIAccessibility.convertToScreenCoordinates(path, in: view)
        let inputAfter2 = path.bounds
        
        // Call 3
        let out3 = UIAccessibility.convertToScreenCoordinates(path, in: view)
        let inputAfter3 = path.bounds
        
        // THE BUG MODEL:
        // - Input is mutated in-place with the transform
        // - Output is the SAME path (mutated input)
        // - Therefore after call N: input.origin = original + N*offset
        
        // Verify model for call 1:
        let expectedInput1 = CGPoint(x: original.origin.x + screenOffset.x, y: original.origin.y + screenOffset.y)
        XCTAssertEqual(inputAfter1.origin.x, expectedInput1.x, accuracy: 0.1,
            "After call 1: input should be original+offset. Expected \(expectedInput1.x), got \(inputAfter1.origin.x)")
        
        // Verify model for call 2:
        let expectedInput2 = CGPoint(x: original.origin.x + 2*screenOffset.x, y: original.origin.y + 2*screenOffset.y)
        XCTAssertEqual(inputAfter2.origin.x, expectedInput2.x, accuracy: 0.1,
            "After call 2: input should be original+2*offset. Expected \(expectedInput2.x), got \(inputAfter2.origin.x)")
        
        // Verify model for call 3:
        let expectedInput3 = CGPoint(x: original.origin.x + 3*screenOffset.x, y: original.origin.y + 3*screenOffset.y)
        XCTAssertEqual(inputAfter3.origin.x, expectedInput3.x, accuracy: 0.1,
            "After call 3: input should be original+3*offset. Expected \(expectedInput3.x), got \(inputAfter3.origin.x)")
        
        // Output should equal input after each call (same object)
        XCTAssertEqual(out1.bounds.origin.x, inputAfter1.origin.x, accuracy: 0.1,
            "Output 1 should equal input after call 1")
        XCTAssertEqual(out2.bounds.origin.x, inputAfter2.origin.x, accuracy: 0.1,
            "Output 2 should equal input after call 2")
        XCTAssertEqual(out3.bounds.origin.x, inputAfter3.origin.x, accuracy: 0.1,
            "Output 3 should equal input after call 3")
    }
    
    /// If the model is correct, we can predict output N
    func test_predictOutput() {
        let path = UIBezierPath()
        path.move(to: CGPoint(x: 5, y: 5))
        path.addLine(to: CGPoint(x: 15, y: 15))
        let originalOrigin = path.bounds.origin // (5, 5)
        
        let view = UIView(frame: CGRect(x: 50, y: 100, width: 60, height: 40))
        testView.addSubview(view)
        window.layoutIfNeeded()
        
        let screenOffset = view.convert(CGPoint.zero, to: nil) // (50, 100)
        
        // For read N, output.origin = originalOrigin + N * screenOffset
        for n in 1...5 {
            let output = UIAccessibility.convertToScreenCoordinates(path, in: view)
            
            let expectedX = originalOrigin.x + CGFloat(n) * screenOffset.x
            let expectedY = originalOrigin.y + CGFloat(n) * screenOffset.y
            
            XCTAssertEqual(output.bounds.origin.x, expectedX, accuracy: 0.1,
                "Call \(n): expected X=\(expectedX), got \(output.bounds.origin.x)")
            XCTAssertEqual(output.bounds.origin.y, expectedY, accuracy: 0.1,
                "Call \(n): expected Y=\(expectedY), got \(output.bounds.origin.y)")
        }
    }
    
    /// Use the model to manipulate output
    func test_manipulateOutput() {
        let path = UIBezierPath()
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: 10, y: 10))
        
        let view = UIView(frame: CGRect(x: 100, y: 200, width: 60, height: 40))
        testView.addSubview(view)
        window.layoutIfNeeded()
        
        let screenOffset = view.convert(CGPoint.zero, to: nil) // (100, 200)
        
        // To get output with origin at (300, 400):
        // We need: 0 + N*100 = 300 → N = 3
        // And: 0 + N*200 = 400 → N = 2
        // Hmm, can't satisfy both with integer N
        
        // Let's verify we can at least get (300, 600) by calling 3 times:
        _ = UIAccessibility.convertToScreenCoordinates(path, in: view)
        _ = UIAccessibility.convertToScreenCoordinates(path, in: view)
        let output3 = UIAccessibility.convertToScreenCoordinates(path, in: view)
        
        XCTAssertEqual(output3.bounds.origin.x, 300, accuracy: 0.1,
            "After 3 calls: X should be 300")
        XCTAssertEqual(output3.bounds.origin.y, 600, accuracy: 0.1,
            "After 3 calls: Y should be 600")
    }
    
    /// Reverse: start with mutated path and get back to original
    func test_reverseToOriginal() {
        let path = UIBezierPath()
        path.move(to: CGPoint(x: 10, y: 20))
        path.addLine(to: CGPoint(x: 20, y: 30))
        let originalOrigin = path.bounds.origin // (10, 20)
        
        let view = UIView(frame: CGRect(x: 100, y: 200, width: 60, height: 40))
        testView.addSubview(view)
        window.layoutIfNeeded()
        
        let screenOffset = view.convert(CGPoint.zero, to: nil)
        
        // Mutate 3 times
        _ = UIAccessibility.convertToScreenCoordinates(path, in: view)
        _ = UIAccessibility.convertToScreenCoordinates(path, in: view)
        _ = UIAccessibility.convertToScreenCoordinates(path, in: view)
        
        // Path is now at origin (10 + 300, 20 + 600) = (310, 620)
        let mutatedOrigin = path.bounds.origin
        XCTAssertEqual(mutatedOrigin.x, 310, accuracy: 0.1, "Mutated X should be 310")
        XCTAssertEqual(mutatedOrigin.y, 620, accuracy: 0.1, "Mutated Y should be 620")
        
        // To reverse: apply inverse transform (translate by -3*offset)
        let reverseTransform = CGAffineTransform(translationX: -3*screenOffset.x, y: -3*screenOffset.y)
        path.apply(reverseTransform)
        
        let restoredOrigin = path.bounds.origin
        XCTAssertEqual(restoredOrigin.x, originalOrigin.x, accuracy: 0.1,
            "Restored X should be original")
        XCTAssertEqual(restoredOrigin.y, originalOrigin.y, accuracy: 0.1,
            "Restored Y should be original")
    }
}
