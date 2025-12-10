import XCTest
import UIKit

private class PathView: UIView {
    var relativePath: UIBezierPath?

    override var accessibilityPath: UIBezierPath? {
        get {
            guard let path = relativePath else { return nil }
            return UIAccessibility.convertToScreenCoordinates(path, in: self)
        }
        set { super.accessibilityPath = newValue }
    }
}

/// Tests to understand the exact mutation mechanism
final class MutationMechanismTests: XCTestCase {
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

    /// Verify output is a DIFFERENT object than input
    func test_outputIsDifferentObject() {
        let path = UIBezierPath()
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: 10, y: 10))
        
        let view = PathView(frame: CGRect(x: 100, y: 200, width: 60, height: 40))
        view.relativePath = path
        testView.addSubview(view)
        window.layoutIfNeeded()
        
        let output = view.accessibilityPath!
        
        XCTAssertFalse(path === output, "Output should be a different object")
    }
    
    /// Check if input path is mutated by the call
    func test_inputPathIsMutated() {
        let path = UIBezierPath()
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: 10, y: 10))
        let originalBounds = path.bounds
        
        let view = PathView(frame: CGRect(x: 100, y: 200, width: 60, height: 40))
        view.relativePath = path
        testView.addSubview(view)
        window.layoutIfNeeded()
        
        // Before first read
        XCTAssertEqual(path.bounds, originalBounds, "Input should be unchanged before read")
        
        // After first read
        _ = view.accessibilityPath
        
        // Is input mutated?
        let afterRead = path.bounds
        let wasMutated = afterRead != originalBounds
        
        if wasMutated {
            // Input WAS mutated - this is the bug
            let deltaX = afterRead.origin.x - originalBounds.origin.x
            let deltaY = afterRead.origin.y - originalBounds.origin.y
            XCTFail("INPUT WAS MUTATED! Delta: (\(deltaX), \(deltaY))")
        } else {
            XCTAssertTrue(true, "Input was not mutated")
        }
    }
    
    /// Check what the output looks like vs the input
    func test_compareInputAndOutput() {
        let path = UIBezierPath()
        path.move(to: CGPoint(x: 5, y: 5))
        path.addLine(to: CGPoint(x: 15, y: 15))
        let originalBounds = path.bounds
        
        let view = PathView(frame: CGRect(x: 100, y: 200, width: 60, height: 40))
        view.relativePath = path
        testView.addSubview(view)
        window.layoutIfNeeded()
        
        let screenOffset = view.convert(CGPoint.zero, to: nil)
        
        // First read
        let output1 = view.accessibilityPath!
        let inputAfter1 = path.bounds
        
        // Report
        XCTAssertEqual(output1.bounds.origin.x, originalBounds.origin.x + screenOffset.x, accuracy: 0.1,
            "Output 1 X should be original + offset")
        XCTAssertEqual(output1.bounds.origin.y, originalBounds.origin.y + screenOffset.y, accuracy: 0.1,
            "Output 1 Y should be original + offset")
        
        // Is input the same as output?
        XCTAssertEqual(inputAfter1.origin.x, output1.bounds.origin.x, accuracy: 0.1,
            "Input bounds should match output bounds after read")
    }
    
    /// The key insight: output1 == input_after_read1
    func test_outputEqualsInputAfterRead() {
        let path = UIBezierPath()
        path.move(to: CGPoint(x: 5, y: 5))
        path.addLine(to: CGPoint(x: 15, y: 15))
        
        let view = PathView(frame: CGRect(x: 100, y: 200, width: 60, height: 40))
        view.relativePath = path
        testView.addSubview(view)
        window.layoutIfNeeded()
        
        // Multiple reads
        let output1 = view.accessibilityPath!
        let inputAfter1 = path.bounds
        
        let output2 = view.accessibilityPath!
        let inputAfter2 = path.bounds
        
        let output3 = view.accessibilityPath!
        let inputAfter3 = path.bounds
        
        // After each read, input == output (but both are different from before)
        XCTAssertEqual(output1.bounds.origin.x, inputAfter1.origin.x, accuracy: 0.1,
            "After read 1: output == input")
        XCTAssertEqual(output2.bounds.origin.x, inputAfter2.origin.x, accuracy: 0.1,
            "After read 2: output == input")
        XCTAssertEqual(output3.bounds.origin.x, inputAfter3.origin.x, accuracy: 0.1,
            "After read 3: output == input")
        
        // But each subsequent read has different values
        XCTAssertNotEqual(output1.bounds.origin.x, output2.bounds.origin.x, accuracy: 0.1,
            "Output 1 != Output 2")
        XCTAssertNotEqual(output2.bounds.origin.x, output3.bounds.origin.x, accuracy: 0.1,
            "Output 2 != Output 3")
    }
    
    /// What is the mechanism? Does it transform the CGPath internally?
    func test_inspectCGPathElements() {
        let path = UIBezierPath()
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: 10, y: 10))
        
        // Get initial elements
        var initialPoints: [CGPoint] = []
        path.cgPath.applyWithBlock { element in
            switch element.pointee.type {
            case .moveToPoint, .addLineToPoint:
                initialPoints.append(element.pointee.points[0])
            default:
                break
            }
        }
        
        let view = PathView(frame: CGRect(x: 100, y: 200, width: 60, height: 40))
        view.relativePath = path
        testView.addSubview(view)
        window.layoutIfNeeded()
        
        let screenOffset = view.convert(CGPoint.zero, to: nil)
        
        // Read once
        _ = view.accessibilityPath
        
        // Get elements after read
        var afterPoints: [CGPoint] = []
        path.cgPath.applyWithBlock { element in
            switch element.pointee.type {
            case .moveToPoint, .addLineToPoint:
                afterPoints.append(element.pointee.points[0])
            default:
                break
            }
        }
        
        // Check if points were transformed
        XCTAssertEqual(afterPoints.count, initialPoints.count, "Should have same number of points")
        
        for i in 0..<min(initialPoints.count, afterPoints.count) {
            let deltaX = afterPoints[i].x - initialPoints[i].x
            let deltaY = afterPoints[i].y - initialPoints[i].y
            
            XCTAssertEqual(deltaX, screenOffset.x, accuracy: 0.1,
                "Point \(i) X should be offset by screenOffset.x")
            XCTAssertEqual(deltaY, screenOffset.y, accuracy: 0.1,
                "Point \(i) Y should be offset by screenOffset.y")
        }
    }
}
