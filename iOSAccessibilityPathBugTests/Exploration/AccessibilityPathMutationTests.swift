import XCTest
import UIKit

/// A view that stores a relative path and converts it to screen coordinates.
private class BuggyAccessibilityPathView: UIView {
    var relativePath: UIBezierPath?

    override var accessibilityPath: UIBezierPath? {
        get {
            guard let path = relativePath else { return nil }
            return UIAccessibility.convertToScreenCoordinates(path, in: self)
        }
        set { super.accessibilityPath = newValue }
    }
}

final class AccessibilityPathMutationTests: XCTestCase {
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
    
    // MARK: - Helper
    
    private func runMultipleReadTest(pathName: String, path: UIBezierPath, file: StaticString = #file, line: UInt = #line) {
        let view = BuggyAccessibilityPathView(frame: CGRect(x: 100, y: 200, width: 60, height: 40))
        view.relativePath = path
        testView.addSubview(view)
        window.layoutIfNeeded()
        
        let expectedX = view.convert(view.bounds, to: nil).origin.x + path.bounds.origin.x
        
        for i in 1...3 {
            let p = view.accessibilityPath!
            XCTAssertEqual(p.bounds.origin.x, expectedX, accuracy: 1.0,
                "\(pathName) read \(i): expected X=\(expectedX), got \(p.bounds.origin.x)", file: file, line: line)
        }
        
        view.removeFromSuperview()
    }

    // MARK: - Convenience Initializers (NO BUG)
    
    func test_rect_noBug() {
        runMultipleReadTest(pathName: "rect", 
            path: UIBezierPath(rect: CGRect(x: 0, y: 0, width: 60, height: 40)))
    }
    
    func test_oval_noBug() {
        runMultipleReadTest(pathName: "oval", 
            path: UIBezierPath(ovalIn: CGRect(x: 0, y: 0, width: 60, height: 40)))
    }
    
    func test_arc_noBug() {
        runMultipleReadTest(pathName: "arc", 
            path: UIBezierPath(arcCenter: CGPoint(x: 30, y: 20), radius: 20, startAngle: 0, endAngle: .pi * 2, clockwise: true))
    }
    
    // MARK: - Explicit Path Elements (HAS BUG)
    
    func test_roundedRect_hasBug() {
        runMultipleReadTest(pathName: "roundedRect", 
            path: UIBezierPath(roundedRect: CGRect(x: 0, y: 0, width: 60, height: 40), cornerRadius: 10))
    }
    
    func test_addLine_hasBug() {
        let path = UIBezierPath()
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: 60, y: 0))
        path.addLine(to: CGPoint(x: 60, y: 40))
        path.addLine(to: CGPoint(x: 0, y: 40))
        path.close()
        runMultipleReadTest(pathName: "addLine", path: path)
    }
    
    func test_addQuadCurve_hasBug() {
        let path = UIBezierPath()
        path.move(to: CGPoint(x: 0, y: 20))
        path.addQuadCurve(to: CGPoint(x: 60, y: 20), controlPoint: CGPoint(x: 30, y: 0))
        runMultipleReadTest(pathName: "quadCurve", path: path)
    }
    
    func test_addCurve_hasBug() {
        let path = UIBezierPath()
        path.move(to: CGPoint(x: 0, y: 20))
        path.addCurve(to: CGPoint(x: 60, y: 20), controlPoint1: CGPoint(x: 20, y: 0), controlPoint2: CGPoint(x: 40, y: 0))
        runMultipleReadTest(pathName: "cubicCurve", path: path)
    }
    
    // MARK: - Edge Cases: Mixing Path Types
    
    /// Rect created via convenience, then line added - does adding a line break it?
    func test_rectThenAddLine() {
        let path = UIBezierPath(rect: CGRect(x: 0, y: 0, width: 60, height: 40))
        path.move(to: CGPoint(x: 30, y: 20))
        path.addLine(to: CGPoint(x: 30, y: 30))
        runMultipleReadTest(pathName: "rectThenAddLine", path: path)
    }
    
    /// Oval created via convenience, then line added
    func test_ovalThenAddLine() {
        let path = UIBezierPath(ovalIn: CGRect(x: 0, y: 0, width: 60, height: 40))
        path.move(to: CGPoint(x: 30, y: 20))
        path.addLine(to: CGPoint(x: 30, y: 30))
        runMultipleReadTest(pathName: "ovalThenAddLine", path: path)
    }
    
    /// Line path, then append a rect
    func test_lineThenAppendRect() {
        let linePath = UIBezierPath()
        linePath.move(to: CGPoint(x: 0, y: 0))
        linePath.addLine(to: CGPoint(x: 10, y: 10))
        
        let rectPath = UIBezierPath(rect: CGRect(x: 20, y: 20, width: 30, height: 20))
        linePath.append(rectPath)
        
        runMultipleReadTest(pathName: "lineThenAppendRect", path: linePath)
    }
    
    /// Rect path, then append a line path
    func test_rectThenAppendLine() {
        let rectPath = UIBezierPath(rect: CGRect(x: 0, y: 0, width: 30, height: 20))
        
        let linePath = UIBezierPath()
        linePath.move(to: CGPoint(x: 40, y: 0))
        linePath.addLine(to: CGPoint(x: 60, y: 40))
        
        rectPath.append(linePath)
        
        runMultipleReadTest(pathName: "rectThenAppendLine", path: rectPath)
    }
    
    // MARK: - Edge Cases: CGPath Conversion
    
    /// Create path from CGPath - does CGPath conversion affect the bug?
    func test_cgPathFromRect() {
        let cgPath = CGPath(rect: CGRect(x: 0, y: 0, width: 60, height: 40), transform: nil)
        let path = UIBezierPath(cgPath: cgPath)
        runMultipleReadTest(pathName: "cgPathFromRect", path: path)
    }
    
    /// Create CGPath with lines, convert to UIBezierPath
    func test_cgPathWithLines() {
        let cgPath = CGMutablePath()
        cgPath.move(to: CGPoint(x: 0, y: 0))
        cgPath.addLine(to: CGPoint(x: 60, y: 0))
        cgPath.addLine(to: CGPoint(x: 60, y: 40))
        cgPath.addLine(to: CGPoint(x: 0, y: 40))
        cgPath.closeSubpath()
        
        let path = UIBezierPath(cgPath: cgPath)
        runMultipleReadTest(pathName: "cgPathWithLines", path: path)
    }
    
    /// Get cgPath from UIBezierPath(rect:), then create new UIBezierPath from it
    func test_rectToCGPathAndBack() {
        let originalPath = UIBezierPath(rect: CGRect(x: 0, y: 0, width: 60, height: 40))
        let cgPath = originalPath.cgPath
        let newPath = UIBezierPath(cgPath: cgPath)
        runMultipleReadTest(pathName: "rectToCGPathAndBack", path: newPath)
    }
    
    // MARK: - Edge Cases: Transforms
    
    /// Apply transform to rect path
    func test_rectWithTransform() {
        let path = UIBezierPath(rect: CGRect(x: 0, y: 0, width: 60, height: 40))
        path.apply(CGAffineTransform(translationX: 5, y: 5))
        runMultipleReadTest(pathName: "rectWithTransform", path: path)
    }
    
    /// Apply transform to line path
    func test_lineWithTransform() {
        let path = UIBezierPath()
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: 60, y: 40))
        path.apply(CGAffineTransform(translationX: 5, y: 5))
        runMultipleReadTest(pathName: "lineWithTransform", path: path)
    }
    
    // MARK: - Edge Cases: Empty and Minimal Paths
    
    /// Completely empty path
    func test_emptyPath() {
        let path = UIBezierPath()
        runMultipleReadTest(pathName: "emptyPath", path: path)
    }
    
    /// Path with only move(to:)
    func test_moveOnly() {
        let path = UIBezierPath()
        path.move(to: CGPoint(x: 30, y: 20))
        runMultipleReadTest(pathName: "moveOnly", path: path)
    }
    
    /// Single point (move then close)
    func test_singlePoint() {
        let path = UIBezierPath()
        path.move(to: CGPoint(x: 30, y: 20))
        path.close()
        runMultipleReadTest(pathName: "singlePoint", path: path)
    }
    
    // MARK: - Edge Cases: View at Origin
    
    /// View at (0,0) - no offset to add
    func test_viewAtOrigin_line() {
        let view = BuggyAccessibilityPathView(frame: CGRect(x: 0, y: 0, width: 60, height: 40))
        let path = UIBezierPath()
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: 60, y: 40))
        view.relativePath = path
        testView.addSubview(view)
        window.layoutIfNeeded()
        
        let expected = view.convert(view.bounds, to: nil).origin
        
        for i in 1...3 {
            let p = view.accessibilityPath!
            XCTAssertEqual(p.bounds.origin.x, expected.x, accuracy: 1.0,
                "viewAtOrigin read \(i): expected X=\(expected.x), got \(p.bounds.origin.x)")
        }
    }
    
    // MARK: - Edge Cases: Negative Coordinates
    
    /// Path with negative coordinates
    func test_negativeCoordinates() {
        let path = UIBezierPath()
        path.move(to: CGPoint(x: -10, y: -10))
        path.addLine(to: CGPoint(x: 50, y: 30))
        runMultipleReadTest(pathName: "negativeCoords", path: path)
    }
    
    // MARK: - Edge Cases: Very Large Coordinates
    
    /// Path with large coordinates
    func test_largeCoordinates() {
        let path = UIBezierPath()
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: 10000, y: 10000))
        runMultipleReadTest(pathName: "largeCoords", path: path)
    }
    
    // MARK: - Edge Cases: Multiple Subpaths
    
    /// Multiple separate subpaths via move
    func test_multipleSubpaths() {
        let path = UIBezierPath()
        // First subpath
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: 20, y: 0))
        path.addLine(to: CGPoint(x: 20, y: 20))
        path.close()
        // Second subpath
        path.move(to: CGPoint(x: 30, y: 10))
        path.addLine(to: CGPoint(x: 50, y: 10))
        path.addLine(to: CGPoint(x: 50, y: 30))
        path.close()
        runMultipleReadTest(pathName: "multipleSubpaths", path: path)
    }
    
    // MARK: - Edge Cases: Copied Path
    
    /// Copy a buggy path - does the copy also have the bug?
    func test_copiedLinePath() {
        let original = UIBezierPath()
        original.move(to: CGPoint(x: 0, y: 0))
        original.addLine(to: CGPoint(x: 60, y: 40))
        
        let copied = original.copy() as! UIBezierPath
        runMultipleReadTest(pathName: "copiedLinePath", path: copied)
    }
    
    /// Copy a working path - does it stay working?
    func test_copiedRectPath() {
        let original = UIBezierPath(rect: CGRect(x: 0, y: 0, width: 60, height: 40))
        let copied = original.copy() as! UIBezierPath
        runMultipleReadTest(pathName: "copiedRectPath", path: copied)
    }
    
    // MARK: - Edge Cases: Reversed Path
    
    /// Reverse a line path
    func test_reversedLinePath() {
        let path = UIBezierPath()
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: 60, y: 40))
        let reversed = path.reversing()
        runMultipleReadTest(pathName: "reversedLinePath", path: reversed)
    }
    
    /// Reverse a rect path
    func test_reversedRectPath() {
        let path = UIBezierPath(rect: CGRect(x: 0, y: 0, width: 60, height: 40))
        let reversed = path.reversing()
        runMultipleReadTest(pathName: "reversedRectPath", path: reversed)
    }
}
