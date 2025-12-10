import XCTest
import UIKit

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

final class MoreEdgeCaseTests: XCTestCase {
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
    
    // MARK: - Accessibility Settings
    
    /// View with isAccessibilityElement = false
    func test_accessibilityElementFalse() {
        let view = BuggyAccessibilityPathView(frame: CGRect(x: 100, y: 200, width: 60, height: 40))
        view.isAccessibilityElement = false
        let path = UIBezierPath()
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: 60, y: 40))
        view.relativePath = path
        testView.addSubview(view)
        window.layoutIfNeeded()
        
        let expectedX = view.convert(view.bounds, to: nil).origin.x
        
        for i in 1...3 {
            let p = view.accessibilityPath!
            XCTAssertEqual(p.bounds.origin.x, expectedX, accuracy: 1.0,
                "isAccessibilityElement=false read \(i): expected \(expectedX), got \(p.bounds.origin.x)")
        }
    }
    
    /// View with isAccessibilityElement = true
    func test_accessibilityElementTrue() {
        let view = BuggyAccessibilityPathView(frame: CGRect(x: 100, y: 200, width: 60, height: 40))
        view.isAccessibilityElement = true
        let path = UIBezierPath()
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: 60, y: 40))
        view.relativePath = path
        testView.addSubview(view)
        window.layoutIfNeeded()
        
        let expectedX = view.convert(view.bounds, to: nil).origin.x
        
        for i in 1...3 {
            let p = view.accessibilityPath!
            XCTAssertEqual(p.bounds.origin.x, expectedX, accuracy: 1.0,
                "isAccessibilityElement=true read \(i): expected \(expectedX), got \(p.bounds.origin.x)")
        }
    }
    
    /// accessibilityElementsHidden on superview
    func test_accessibilityElementsHidden() {
        testView.accessibilityElementsHidden = true
        
        let view = BuggyAccessibilityPathView(frame: CGRect(x: 100, y: 200, width: 60, height: 40))
        let path = UIBezierPath()
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: 60, y: 40))
        view.relativePath = path
        testView.addSubview(view)
        window.layoutIfNeeded()
        
        let expectedX = view.convert(view.bounds, to: nil).origin.x
        
        for i in 1...3 {
            let p = view.accessibilityPath!
            XCTAssertEqual(p.bounds.origin.x, expectedX, accuracy: 1.0,
                "accessibilityElementsHidden read \(i): expected \(expectedX), got \(p.bounds.origin.x)")
        }
    }
    
    // MARK: - Transform Tests
    
    /// View with transform (rotation)
    func test_viewWithRotationTransform() {
        let view = BuggyAccessibilityPathView(frame: CGRect(x: 100, y: 200, width: 60, height: 40))
        view.transform = CGAffineTransform(rotationAngle: .pi / 4)
        let path = UIBezierPath()
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: 60, y: 40))
        view.relativePath = path
        testView.addSubview(view)
        window.layoutIfNeeded()
        
        // With rotation, coordinates are complex - just check consistency
        let firstRead = view.accessibilityPath!.bounds
        
        for i in 2...3 {
            let p = view.accessibilityPath!
            XCTAssertEqual(p.bounds.origin.x, firstRead.origin.x, accuracy: 1.0,
                "Rotated view read \(i): should match first read \(firstRead.origin.x), got \(p.bounds.origin.x)")
        }
    }
    
    /// View with scale transform
    func test_viewWithScaleTransform() {
        let view = BuggyAccessibilityPathView(frame: CGRect(x: 100, y: 200, width: 60, height: 40))
        view.transform = CGAffineTransform(scaleX: 2, y: 2)
        let path = UIBezierPath()
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: 60, y: 40))
        view.relativePath = path
        testView.addSubview(view)
        window.layoutIfNeeded()
        
        let firstRead = view.accessibilityPath!.bounds
        
        for i in 2...3 {
            let p = view.accessibilityPath!
            XCTAssertEqual(p.bounds.origin.x, firstRead.origin.x, accuracy: 1.0,
                "Scaled view read \(i): should match first read \(firstRead.origin.x), got \(p.bounds.origin.x)")
        }
    }
    
    /// Superview with transform
    func test_superviewWithTransform() {
        let container = UIView(frame: CGRect(x: 50, y: 50, width: 200, height: 200))
        container.transform = CGAffineTransform(translationX: 20, y: 30)
        testView.addSubview(container)
        
        let view = BuggyAccessibilityPathView(frame: CGRect(x: 50, y: 50, width: 60, height: 40))
        let path = UIBezierPath()
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: 60, y: 40))
        view.relativePath = path
        container.addSubview(view)
        window.layoutIfNeeded()
        
        let firstRead = view.accessibilityPath!.bounds
        
        for i in 2...3 {
            let p = view.accessibilityPath!
            XCTAssertEqual(p.bounds.origin.x, firstRead.origin.x, accuracy: 1.0,
                "Superview transform read \(i): should match first read \(firstRead.origin.x), got \(p.bounds.origin.x)")
        }
    }
    
    // MARK: - UIScrollView
    
    /// View inside scrollview
    func test_viewInsideScrollView() {
        let scrollView = UIScrollView(frame: CGRect(x: 0, y: 0, width: 400, height: 400))
        scrollView.contentSize = CGSize(width: 800, height: 800)
        testView.addSubview(scrollView)
        
        let view = BuggyAccessibilityPathView(frame: CGRect(x: 100, y: 200, width: 60, height: 40))
        let path = UIBezierPath()
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: 60, y: 40))
        view.relativePath = path
        scrollView.addSubview(view)
        window.layoutIfNeeded()
        
        let expectedX = view.convert(view.bounds, to: nil).origin.x
        
        for i in 1...3 {
            let p = view.accessibilityPath!
            XCTAssertEqual(p.bounds.origin.x, expectedX, accuracy: 1.0,
                "ScrollView read \(i): expected \(expectedX), got \(p.bounds.origin.x)")
        }
    }
    
    /// View inside scrolled scrollview
    func test_viewInsideScrolledScrollView() {
        let scrollView = UIScrollView(frame: CGRect(x: 0, y: 0, width: 400, height: 400))
        scrollView.contentSize = CGSize(width: 800, height: 800)
        scrollView.contentOffset = CGPoint(x: 50, y: 100)
        testView.addSubview(scrollView)
        
        let view = BuggyAccessibilityPathView(frame: CGRect(x: 100, y: 200, width: 60, height: 40))
        let path = UIBezierPath()
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: 60, y: 40))
        view.relativePath = path
        scrollView.addSubview(view)
        window.layoutIfNeeded()
        
        let expectedX = view.convert(view.bounds, to: nil).origin.x
        
        for i in 1...3 {
            let p = view.accessibilityPath!
            XCTAssertEqual(p.bounds.origin.x, expectedX, accuracy: 1.0,
                "Scrolled ScrollView read \(i): expected \(expectedX), got \(p.bounds.origin.x)")
        }
    }
    
    // MARK: - Multiple Windows
    
    /// Second window scenario
    func test_secondWindow() {
        let secondWindow = UIWindow(frame: CGRect(x: 0, y: 0, width: 400, height: 800))
        let secondTestView = UIView(frame: secondWindow.bounds)
        secondWindow.addSubview(secondTestView)
        secondWindow.makeKeyAndVisible()
        
        let view = BuggyAccessibilityPathView(frame: CGRect(x: 100, y: 200, width: 60, height: 40))
        let path = UIBezierPath()
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: 60, y: 40))
        view.relativePath = path
        secondTestView.addSubview(view)
        secondWindow.layoutIfNeeded()
        
        let expectedX = view.convert(view.bounds, to: nil).origin.x
        
        for i in 1...3 {
            let p = view.accessibilityPath!
            XCTAssertEqual(p.bounds.origin.x, expectedX, accuracy: 1.0,
                "Second window read \(i): expected \(expectedX), got \(p.bounds.origin.x)")
        }
        
        secondWindow.isHidden = true
    }
    
    // MARK: - Different View Types
    
    /// UILabel subclass
    func test_labelSubclass() {
        class BuggyLabel: UILabel {
            var relativePath: UIBezierPath?
            override var accessibilityPath: UIBezierPath? {
                get {
                    guard let path = relativePath else { return nil }
                    return UIAccessibility.convertToScreenCoordinates(path, in: self)
                }
                set { super.accessibilityPath = newValue }
            }
        }
        
        let label = BuggyLabel(frame: CGRect(x: 100, y: 200, width: 60, height: 40))
        label.text = "Test"
        let path = UIBezierPath()
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: 60, y: 40))
        label.relativePath = path
        testView.addSubview(label)
        window.layoutIfNeeded()
        
        let expectedX = label.convert(label.bounds, to: nil).origin.x
        
        for i in 1...3 {
            let p = label.accessibilityPath!
            XCTAssertEqual(p.bounds.origin.x, expectedX, accuracy: 1.0,
                "UILabel read \(i): expected \(expectedX), got \(p.bounds.origin.x)")
        }
    }
    
    /// UIButton subclass
    func test_buttonSubclass() {
        class BuggyButton: UIButton {
            var relativePath: UIBezierPath?
            override var accessibilityPath: UIBezierPath? {
                get {
                    guard let path = relativePath else { return nil }
                    return UIAccessibility.convertToScreenCoordinates(path, in: self)
                }
                set { super.accessibilityPath = newValue }
            }
        }
        
        let button = BuggyButton(frame: CGRect(x: 100, y: 200, width: 60, height: 40))
        button.setTitle("Test", for: .normal)
        let path = UIBezierPath()
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: 60, y: 40))
        button.relativePath = path
        testView.addSubview(button)
        window.layoutIfNeeded()
        
        let expectedX = button.convert(button.bounds, to: nil).origin.x
        
        for i in 1...3 {
            let p = button.accessibilityPath!
            XCTAssertEqual(p.bounds.origin.x, expectedX, accuracy: 1.0,
                "UIButton read \(i): expected \(expectedX), got \(p.bounds.origin.x)")
        }
    }
    
    // MARK: - Timing / Async
    
    /// Read path after delay
    func test_readAfterDelay() {
        let view = BuggyAccessibilityPathView(frame: CGRect(x: 100, y: 200, width: 60, height: 40))
        let path = UIBezierPath()
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: 60, y: 40))
        view.relativePath = path
        testView.addSubview(view)
        window.layoutIfNeeded()
        
        let expectedX = view.convert(view.bounds, to: nil).origin.x
        
        let expectation = self.expectation(description: "delay")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            for i in 1...3 {
                let p = view.accessibilityPath!
                XCTAssertEqual(p.bounds.origin.x, expectedX, accuracy: 1.0,
                    "After delay read \(i): expected \(expectedX), got \(p.bounds.origin.x)")
            }
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 1)
    }
    
    // MARK: - Layout
    
    /// Read before layoutIfNeeded
    func test_readBeforeLayout() {
        let view = BuggyAccessibilityPathView(frame: CGRect(x: 100, y: 200, width: 60, height: 40))
        let path = UIBezierPath()
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: 60, y: 40))
        view.relativePath = path
        testView.addSubview(view)
        // NOT calling layoutIfNeeded
        
        let expectedX = view.convert(view.bounds, to: nil).origin.x
        
        for i in 1...3 {
            let p = view.accessibilityPath!
            XCTAssertEqual(p.bounds.origin.x, expectedX, accuracy: 1.0,
                "Before layout read \(i): expected \(expectedX), got \(p.bounds.origin.x)")
        }
    }
    
    /// Change frame between reads
    func test_changeFrameBetweenReads() {
        let view = BuggyAccessibilityPathView(frame: CGRect(x: 100, y: 200, width: 60, height: 40))
        let path = UIBezierPath()
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: 60, y: 40))
        view.relativePath = path
        testView.addSubview(view)
        window.layoutIfNeeded()
        
        // Read once at original position
        let firstRead = view.accessibilityPath!
        let firstExpected = view.convert(view.bounds, to: nil).origin.x
        XCTAssertEqual(firstRead.bounds.origin.x, firstExpected, accuracy: 1.0)
        
        // Move view
        view.frame.origin = CGPoint(x: 200, y: 300)
        window.layoutIfNeeded()
        
        // Read at new position
        let secondExpected = view.convert(view.bounds, to: nil).origin.x
        let secondRead = view.accessibilityPath!
        XCTAssertEqual(secondRead.bounds.origin.x, secondExpected, accuracy: 1.0,
            "After move: expected \(secondExpected), got \(secondRead.bounds.origin.x)")
    }
    
    // MARK: - Returning Different Path
    
    /// What if getter returns a different path each time?
    func test_differentPathEachRead() {
        class FreshPathView: UIView {
            override var accessibilityPath: UIBezierPath? {
                get {
                    // Create a NEW path each time
                    let path = UIBezierPath()
                    path.move(to: CGPoint(x: 0, y: 0))
                    path.addLine(to: CGPoint(x: 60, y: 40))
                    return UIAccessibility.convertToScreenCoordinates(path, in: self)
                }
                set { super.accessibilityPath = newValue }
            }
        }
        
        let view = FreshPathView(frame: CGRect(x: 100, y: 200, width: 60, height: 40))
        testView.addSubview(view)
        window.layoutIfNeeded()
        
        let expectedX = view.convert(view.bounds, to: nil).origin.x
        
        for i in 1...3 {
            let p = view.accessibilityPath!
            XCTAssertEqual(p.bounds.origin.x, expectedX, accuracy: 1.0,
                "Fresh path read \(i): expected \(expectedX), got \(p.bounds.origin.x)")
        }
    }
}
