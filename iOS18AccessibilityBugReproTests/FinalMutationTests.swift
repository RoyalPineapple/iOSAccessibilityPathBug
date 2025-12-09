import XCTest
import UIKit

/// Final definitive tests to understand the mutation
final class FinalMutationTests: XCTestCase {
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

    /// Direct API test with explicit checks
    func test_directAPIBehavior() {
        let path = UIBezierPath()
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: 10, y: 10))
        
        let view = UIView(frame: CGRect(x: 100, y: 200, width: 60, height: 40))
        testView.addSubview(view)
        window.layoutIfNeeded()
        
        // Record everything
        let originalInputBounds = path.bounds
        
        // First call
        let output1 = UIAccessibility.convertToScreenCoordinates(path, in: view)
        let inputAfterCall1 = path.bounds
        let output1Bounds = output1.bounds
        
        // Check: was input mutated?
        let inputMutatedCall1 = (inputAfterCall1 != originalInputBounds)
        
        // Second call
        let output2 = UIAccessibility.convertToScreenCoordinates(path, in: view)
        let inputAfterCall2 = path.bounds
        let output2Bounds = output2.bounds
        
        // Check: was input mutated between calls?
        let inputMutatedCall2 = (inputAfterCall2 != inputAfterCall1)
        
        // Check: are outputs different?
        let outputsDiffer = (output1Bounds != output2Bounds)
        
        // Report findings via assertions
        if inputMutatedCall1 {
            let dx = inputAfterCall1.origin.x - originalInputBounds.origin.x
            let dy = inputAfterCall1.origin.y - originalInputBounds.origin.y
            // This assertion will show in test results
            XCTAssertEqual(dx, 0, accuracy: 0.1, 
                "BUG: Input mutated after call 1 by dx=\(dx), dy=\(dy)")
        }
        
        if inputMutatedCall2 {
            let dx = inputAfterCall2.origin.x - inputAfterCall1.origin.x
            let dy = inputAfterCall2.origin.y - inputAfterCall1.origin.y
            XCTAssertEqual(dx, 0, accuracy: 0.1,
                "BUG: Input mutated after call 2 by dx=\(dx), dy=\(dy)")
        }
        
        if outputsDiffer {
            let dx = output2Bounds.origin.x - output1Bounds.origin.x
            let dy = output2Bounds.origin.y - output1Bounds.origin.y
            XCTAssertEqual(dx, 0, accuracy: 0.1,
                "BUG: Outputs differ by dx=\(dx), dy=\(dy)")
        }
        
        // If none mutated, that's correct behavior
        if !inputMutatedCall1 && !inputMutatedCall2 && !outputsDiffer {
            XCTAssertTrue(true, "API behaves correctly with direct calls")
        }
    }
    
    /// Via accessibilityPath getter
    func test_viaAccessibilityPathGetter() {
        class PathView: UIView {
            var relativePath: UIBezierPath?
            override var accessibilityPath: UIBezierPath? {
                get {
                    guard let path = relativePath else { return nil }
                    return UIAccessibility.convertToScreenCoordinates(path, in: self)
                }
                set { super.accessibilityPath = newValue }
            }
        }
        
        let path = UIBezierPath()
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: 10, y: 10))
        
        let view = PathView(frame: CGRect(x: 100, y: 200, width: 60, height: 40))
        view.relativePath = path
        testView.addSubview(view)
        window.layoutIfNeeded()
        
        let originalInputBounds = path.bounds
        
        // First access
        let output1 = view.accessibilityPath!
        let inputAfterAccess1 = path.bounds
        let output1Bounds = output1.bounds
        
        // Second access
        let output2 = view.accessibilityPath!
        let inputAfterAccess2 = path.bounds
        let output2Bounds = output2.bounds
        
        // Report
        let inputMutated1 = (inputAfterAccess1 != originalInputBounds)
        let inputMutated2 = (inputAfterAccess2 != inputAfterAccess1)
        let outputsDiffer = (output1Bounds != output2Bounds)
        
        if inputMutated1 {
            let dx = inputAfterAccess1.origin.x - originalInputBounds.origin.x
            XCTAssertEqual(dx, 0, accuracy: 0.1,
                "VIA GETTER - Input mutated after access 1 by dx=\(dx)")
        }
        
        if inputMutated2 {
            let dx = inputAfterAccess2.origin.x - inputAfterAccess1.origin.x
            XCTAssertEqual(dx, 0, accuracy: 0.1,
                "VIA GETTER - Input mutated after access 2 by dx=\(dx)")
        }
        
        if outputsDiffer {
            let dx = output2Bounds.origin.x - output1Bounds.origin.x
            XCTAssertEqual(dx, 0, accuracy: 0.1,
                "VIA GETTER - Outputs differ by dx=\(dx)")
        }
    }
}
