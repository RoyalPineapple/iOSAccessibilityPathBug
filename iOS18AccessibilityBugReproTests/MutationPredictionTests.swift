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

/// Tests to understand and predict the mutation behavior
final class MutationPredictionTests: XCTestCase {
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

    /// The mutation adds the screen offset to the input path each read
    func test_mutationAddsScreenOffsetEachRead() {
        let path = UIBezierPath()
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: 10, y: 10))
        
        let view = PathView(frame: CGRect(x: 100, y: 200, width: 60, height: 40))
        view.relativePath = path
        testView.addSubview(view)
        window.layoutIfNeeded()
        
        let screenOffset = view.convert(CGPoint.zero, to: nil)
        
        // Collect output bounds for 5 reads
        var outputs: [CGRect] = []
        for _ in 1...5 {
            outputs.append(view.accessibilityPath!.bounds)
        }
        
        // Check that each read adds exactly the screen offset
        for i in 1..<outputs.count {
            let deltaX = outputs[i].origin.x - outputs[i-1].origin.x
            let deltaY = outputs[i].origin.y - outputs[i-1].origin.y
            
            XCTAssertEqual(deltaX, screenOffset.x, accuracy: 0.1,
                "Delta X between reads should equal screen offset X (\(screenOffset.x))")
            XCTAssertEqual(deltaY, screenOffset.y, accuracy: 0.1,
                "Delta Y between reads should equal screen offset Y (\(screenOffset.y))")
        }
    }
    
    /// View at origin (0,0) should have no mutation (offset is 0)
    func test_viewAtOriginNoMutation() {
        let path = UIBezierPath()
        path.move(to: CGPoint(x: 5, y: 5))
        path.addLine(to: CGPoint(x: 15, y: 15))
        
        let view = PathView(frame: CGRect(x: 0, y: 0, width: 60, height: 40))
        view.relativePath = path
        testView.addSubview(view)
        window.layoutIfNeeded()
        
        let screenOffset = view.convert(CGPoint.zero, to: nil)
        XCTAssertEqual(screenOffset.x, 0, accuracy: 0.1, "View at origin should have 0 screen offset X")
        XCTAssertEqual(screenOffset.y, 0, accuracy: 0.1, "View at origin should have 0 screen offset Y")
        
        // Multiple reads should return same bounds
        let first = view.accessibilityPath!.bounds
        let second = view.accessibilityPath!.bounds
        let third = view.accessibilityPath!.bounds
        
        XCTAssertEqual(first.origin.x, second.origin.x, accuracy: 0.1, "Views at origin should not mutate")
        XCTAssertEqual(second.origin.x, third.origin.x, accuracy: 0.1, "Views at origin should not mutate")
    }
    
    /// Can predict read N: output origin = original + (N * screenOffset)
    func test_predictReadN() {
        let path = UIBezierPath()
        path.move(to: CGPoint(x: 5, y: 5))
        path.addLine(to: CGPoint(x: 15, y: 15))
        let originalOrigin = path.bounds.origin
        
        let view = PathView(frame: CGRect(x: 50, y: 100, width: 60, height: 40))
        view.relativePath = path
        testView.addSubview(view)
        window.layoutIfNeeded()
        
        let screenOffset = view.convert(CGPoint.zero, to: nil)
        
        // Formula: Read N output origin = originalOrigin + (N * screenOffset)
        for n in 1...5 {
            let output = view.accessibilityPath!
            
            let predictedX = originalOrigin.x + (CGFloat(n) * screenOffset.x)
            let predictedY = originalOrigin.y + (CGFloat(n) * screenOffset.y)
            
            XCTAssertEqual(output.bounds.origin.x, predictedX, accuracy: 0.1,
                "Read \(n) X should be \(predictedX)")
            XCTAssertEqual(output.bounds.origin.y, predictedY, accuracy: 0.1,
                "Read \(n) Y should be \(predictedY)")
        }
    }
    
    /// Input and output are the SAME object (not a copy)
    func test_inputAndOutputAreSameObject() {
        let path = UIBezierPath()
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: 10, y: 10))
        
        let view = PathView(frame: CGRect(x: 100, y: 200, width: 60, height: 40))
        view.relativePath = path
        testView.addSubview(view)
        window.layoutIfNeeded()
        
        let output = view.accessibilityPath!
        
        // Check if they are the same object
        XCTAssertTrue(path === output, "Input and output should be the same object (bug!)")
    }
    
    /// The input path bounds grow after each read
    func test_inputPathGrowsAfterRead() {
        let path = UIBezierPath()
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: 10, y: 10))
        let originalBounds = path.bounds
        
        let view = PathView(frame: CGRect(x: 100, y: 200, width: 60, height: 40))
        view.relativePath = path
        testView.addSubview(view)
        window.layoutIfNeeded()
        
        let screenOffset = view.convert(CGPoint.zero, to: nil)
        
        // After first read, input path should have offset added
        _ = view.accessibilityPath
        let afterFirst = path.bounds
        
        XCTAssertEqual(afterFirst.origin.x, originalBounds.origin.x + screenOffset.x, accuracy: 0.1,
            "Input path X should be original + screenOffset after first read")
        XCTAssertEqual(afterFirst.origin.y, originalBounds.origin.y + screenOffset.y, accuracy: 0.1,
            "Input path Y should be original + screenOffset after first read")
        
        // After second read, another offset added
        _ = view.accessibilityPath
        let afterSecond = path.bounds
        
        XCTAssertEqual(afterSecond.origin.x, originalBounds.origin.x + (2 * screenOffset.x), accuracy: 0.1,
            "Input path X should be original + 2*screenOffset after second read")
    }
    
    /// Can reverse-calculate to get correct path from mutated one
    func test_reverseCalculation() {
        let path = UIBezierPath()
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: 10, y: 10))
        let originalOrigin = path.bounds.origin
        
        let view = PathView(frame: CGRect(x: 50, y: 100, width: 60, height: 40))
        view.relativePath = path
        testView.addSubview(view)
        window.layoutIfNeeded()
        
        let screenOffset = view.convert(CGPoint.zero, to: nil)
        
        // Read 3 times (path is now mutated with 3 offsets)
        _ = view.accessibilityPath
        _ = view.accessibilityPath
        let thirdOutput = view.accessibilityPath!
        
        // The path has been mutated 3 times, so to get "correct" screen coords:
        // correctOutput = currentOutput - ((n-1) * screenOffset)
        // where n is the read number
        
        // For read 3, correct = output - 2*offset
        let correctedX = thirdOutput.bounds.origin.x - (2 * screenOffset.x)
        let correctedY = thirdOutput.bounds.origin.y - (2 * screenOffset.y)
        
        // This should equal original + 1*offset (the correct first read)
        let expectedX = originalOrigin.x + screenOffset.x
        let expectedY = originalOrigin.y + screenOffset.y
        
        XCTAssertEqual(correctedX, expectedX, accuracy: 0.1,
            "Can reverse-calculate correct X")
        XCTAssertEqual(correctedY, expectedY, accuracy: 0.1,
            "Can reverse-calculate correct Y")
    }
}
