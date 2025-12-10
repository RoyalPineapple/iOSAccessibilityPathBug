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

final class WindowHierarchyTests: XCTestCase {
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
    
    // MARK: - Window Hierarchy Tests
    
    /// View NOT in any hierarchy - just created
    func test_detachedView_notInHierarchy() {
        let view = BuggyAccessibilityPathView(frame: CGRect(x: 100, y: 200, width: 60, height: 40))
        let path = UIBezierPath()
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: 60, y: 40))
        view.relativePath = path
        
        let originalBounds = path.bounds
        
        // Read multiple times while NOT in hierarchy
        for i in 1...3 {
            let _ = view.accessibilityPath
        }
        
        XCTAssertEqual(path.bounds, originalBounds,
            "Detached view: path should not be mutated. Original: \(originalBounds), After: \(path.bounds)")
    }
    
    /// View added to a view that's NOT in window
    func test_viewInDetachedHierarchy() {
        let container = UIView(frame: CGRect(x: 0, y: 0, width: 200, height: 200))
        // container is NOT added to window
        
        let view = BuggyAccessibilityPathView(frame: CGRect(x: 100, y: 200, width: 60, height: 40))
        let path = UIBezierPath()
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: 60, y: 40))
        view.relativePath = path
        container.addSubview(view)
        
        let originalBounds = path.bounds
        
        for i in 1...3 {
            let _ = view.accessibilityPath
        }
        
        XCTAssertEqual(path.bounds, originalBounds,
            "View in detached hierarchy: path should not be mutated. Original: \(originalBounds), After: \(path.bounds)")
    }
    
    /// View in window hierarchy
    func test_viewInWindowHierarchy() {
        let view = BuggyAccessibilityPathView(frame: CGRect(x: 100, y: 200, width: 60, height: 40))
        let path = UIBezierPath()
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: 60, y: 40))
        view.relativePath = path
        testView.addSubview(view)
        window.layoutIfNeeded()
        
        let originalBounds = path.bounds
        let expectedX = view.convert(view.bounds, to: nil).origin.x
        
        for i in 1...3 {
            let p = view.accessibilityPath!
            XCTAssertEqual(p.bounds.origin.x, expectedX, accuracy: 1.0,
                "In window read \(i): expected \(expectedX), got \(p.bounds.origin.x)")
        }
    }
    
    /// Add to hierarchy AFTER reading while detached
    func test_readWhileDetached_thenAttach() {
        let view = BuggyAccessibilityPathView(frame: CGRect(x: 100, y: 200, width: 60, height: 40))
        let path = UIBezierPath()
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: 60, y: 40))
        view.relativePath = path
        
        // Read while detached
        let _ = view.accessibilityPath
        let _ = view.accessibilityPath
        let boundsAfterDetachedReads = path.bounds
        
        // Now attach
        testView.addSubview(view)
        window.layoutIfNeeded()
        
        let expectedX = view.convert(view.bounds, to: nil).origin.x
        
        // Read while attached
        for i in 1...3 {
            let p = view.accessibilityPath!
            XCTAssertEqual(p.bounds.origin.x, expectedX, accuracy: 1.0,
                "After attach read \(i): expected \(expectedX), got \(p.bounds.origin.x)")
        }
    }
    
    /// Read while attached, then detach, then read again
    func test_readWhileAttached_thenDetach() {
        let view = BuggyAccessibilityPathView(frame: CGRect(x: 100, y: 200, width: 60, height: 40))
        let path = UIBezierPath()
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: 60, y: 40))
        view.relativePath = path
        testView.addSubview(view)
        window.layoutIfNeeded()
        
        // Read while attached
        let _ = view.accessibilityPath
        let _ = view.accessibilityPath
        let boundsAfterAttachedReads = path.bounds
        
        // Detach
        view.removeFromSuperview()
        
        // Read while detached - should these reads add more?
        for i in 1...3 {
            let _ = view.accessibilityPath
        }
        
        // Check if detached reads added more
        XCTAssertEqual(path.bounds, boundsAfterAttachedReads,
            "Detached reads should not add more. After attached: \(boundsAfterAttachedReads), After detached: \(path.bounds)")
    }
    
    /// Window not key/visible
    func test_windowNotKeyOrVisible() {
        let otherWindow = UIWindow(frame: CGRect(x: 0, y: 0, width: 400, height: 800))
        // NOT calling makeKeyAndVisible
        
        let container = UIView(frame: otherWindow.bounds)
        otherWindow.addSubview(container)
        
        let view = BuggyAccessibilityPathView(frame: CGRect(x: 100, y: 200, width: 60, height: 40))
        let path = UIBezierPath()
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: 60, y: 40))
        view.relativePath = path
        container.addSubview(view)
        
        let originalBounds = path.bounds
        
        for i in 1...3 {
            let _ = view.accessibilityPath
        }
        
        // Does it matter if window is key/visible?
        let wasMutated = path.bounds != originalBounds
        if wasMutated {
            XCTFail("Window not key/visible: path was mutated anyway. Original: \(originalBounds), After: \(path.bounds)")
        }
    }
    
    /// Hidden view in hierarchy
    func test_hiddenView() {
        let view = BuggyAccessibilityPathView(frame: CGRect(x: 100, y: 200, width: 60, height: 40))
        view.isHidden = true
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
                "Hidden view read \(i): expected \(expectedX), got \(p.bounds.origin.x)")
        }
    }
    
    /// View with alpha = 0
    func test_zeroAlphaView() {
        let view = BuggyAccessibilityPathView(frame: CGRect(x: 100, y: 200, width: 60, height: 40))
        view.alpha = 0
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
                "Zero alpha view read \(i): expected \(expectedX), got \(p.bounds.origin.x)")
        }
    }
    
    /// View clipped by superview
    func test_clippedView() {
        let container = UIView(frame: CGRect(x: 50, y: 50, width: 50, height: 50))
        container.clipsToBounds = true
        testView.addSubview(container)
        
        let view = BuggyAccessibilityPathView(frame: CGRect(x: 100, y: 200, width: 60, height: 40))
        // View is way outside container's bounds
        let path = UIBezierPath()
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: 60, y: 40))
        view.relativePath = path
        container.addSubview(view)
        window.layoutIfNeeded()
        
        let expectedX = view.convert(view.bounds, to: nil).origin.x
        
        for i in 1...3 {
            let p = view.accessibilityPath!
            XCTAssertEqual(p.bounds.origin.x, expectedX, accuracy: 1.0,
                "Clipped view read \(i): expected \(expectedX), got \(p.bounds.origin.x)")
        }
    }
    
    /// Deeply nested view hierarchy
    func test_deeplyNestedView() {
        var current: UIView = testView
        for _ in 0..<10 {
            let nested = UIView(frame: CGRect(x: 5, y: 5, width: current.bounds.width - 10, height: current.bounds.height - 10))
            current.addSubview(nested)
            current = nested
        }
        
        let view = BuggyAccessibilityPathView(frame: CGRect(x: 10, y: 10, width: 60, height: 40))
        let path = UIBezierPath()
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: 60, y: 40))
        view.relativePath = path
        current.addSubview(view)
        window.layoutIfNeeded()
        
        let expectedX = view.convert(view.bounds, to: nil).origin.x
        
        for i in 1...3 {
            let p = view.accessibilityPath!
            XCTAssertEqual(p.bounds.origin.x, expectedX, accuracy: 1.0,
                "Deeply nested read \(i): expected \(expectedX), got \(p.bounds.origin.x)")
        }
    }
    
    /// Call convertToScreenCoordinates directly (not via accessibilityPath)
    func test_directAPICall_detached() {
        let view = UIView(frame: CGRect(x: 100, y: 200, width: 60, height: 40))
        // NOT in hierarchy
        
        let path = UIBezierPath()
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: 60, y: 40))
        let originalBounds = path.bounds
        
        for _ in 1...3 {
            let _ = UIAccessibility.convertToScreenCoordinates(path, in: view)
        }
        
        XCTAssertEqual(path.bounds, originalBounds,
            "Direct API detached: should not mutate. Original: \(originalBounds), After: \(path.bounds)")
    }
    
    /// Call convertToScreenCoordinates directly while in hierarchy
    func test_directAPICall_attached() {
        let view = UIView(frame: CGRect(x: 100, y: 200, width: 60, height: 40))
        testView.addSubview(view)
        window.layoutIfNeeded()
        
        let path = UIBezierPath()
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: 60, y: 40))
        let originalBounds = path.bounds
        
        for _ in 1...3 {
            let _ = UIAccessibility.convertToScreenCoordinates(path, in: view)
        }
        
        XCTAssertEqual(path.bounds, originalBounds,
            "Direct API attached: should not mutate. Original: \(originalBounds), After: \(path.bounds)")
    }
}
