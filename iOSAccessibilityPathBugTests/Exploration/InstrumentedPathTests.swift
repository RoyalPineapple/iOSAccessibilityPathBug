import XCTest
import UIKit

/// Instrumented UIBezierPath that logs all CGPath access
class InstrumentedBezierPath: UIBezierPath {
    var cgPathGetCount = 0
    var cgPathSetCount = 0
    var lastSetCGPath: CGPath?
    
    private var _backingCGPath: CGPath?
    
    override var cgPath: CGPath {
        get {
            cgPathGetCount += 1
            let result = super.cgPath
            print("  [GET cgPath #\(cgPathGetCount)] bounds: \(result.boundingBox)")
            return result
        }
        set {
            cgPathSetCount += 1
            lastSetCGPath = newValue
            print("  [SET cgPath #\(cgPathSetCount)] bounds: \(newValue.boundingBox)")
            super.cgPath = newValue
        }
    }
    
    func printStats() {
        print("  Stats: \(cgPathGetCount) gets, \(cgPathSetCount) sets")
    }
}

/// Tests using instrumented path
final class InstrumentedPathTests: XCTestCase {
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

    /// Track CGPath access during convertToScreenCoordinates
    func test_trackCGPathAccess() {
        let path = InstrumentedBezierPath()
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: 10, y: 10))
        
        let view = UIView(frame: CGRect(x: 100, y: 200, width: 60, height: 40))
        testView.addSubview(view)
        window.layoutIfNeeded()
        
        print("=== BEFORE FIRST CALL ===")
        print("Path bounds: \(path.bounds)")
        path.cgPathGetCount = 0
        path.cgPathSetCount = 0
        
        print("\n=== CALL 1 ===")
        let out1 = UIAccessibility.convertToScreenCoordinates(path, in: view)
        print("Output bounds: \(out1.bounds)")
        print("Input bounds after: \(path.bounds)")
        path.printStats()
        
        let gets1 = path.cgPathGetCount
        let sets1 = path.cgPathSetCount
        path.cgPathGetCount = 0
        path.cgPathSetCount = 0
        
        print("\n=== CALL 2 ===")
        let out2 = UIAccessibility.convertToScreenCoordinates(path, in: view)
        print("Output bounds: \(out2.bounds)")
        print("Input bounds after: \(path.bounds)")
        path.printStats()
        
        let gets2 = path.cgPathGetCount
        let sets2 = path.cgPathSetCount
        
        // Report findings
        XCTAssertGreaterThan(gets1 + sets1, 0, 
            "Call 1: Expected CGPath access. Gets: \(gets1), Sets: \(sets1)")
        XCTAssertGreaterThan(gets2 + sets2, 0,
            "Call 2: Expected CGPath access. Gets: \(gets2), Sets: \(sets2)")
    }
    
    /// See if cgPath setter is called (mutation via property)
    func test_isCGPathSetterCalled() {
        let path = InstrumentedBezierPath()
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: 10, y: 10))
        
        let view = UIView(frame: CGRect(x: 100, y: 200, width: 60, height: 40))
        testView.addSubview(view)
        window.layoutIfNeeded()
        
        path.cgPathSetCount = 0
        
        _ = UIAccessibility.convertToScreenCoordinates(path, in: view)
        
        if path.cgPathSetCount > 0 {
            XCTFail("cgPath SETTER was called \(path.cgPathSetCount) times - mutation via property!")
        } else {
            // Mutation might happen internally without going through property
            XCTAssertTrue(true, "cgPath setter not called")
        }
    }
    
    /// Check if the CGPath object identity changes
    func test_cgPathObjectIdentity() {
        let path = InstrumentedBezierPath()
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: 10, y: 10))
        
        let view = UIView(frame: CGRect(x: 100, y: 200, width: 60, height: 40))
        testView.addSubview(view)
        window.layoutIfNeeded()
        
        let cgPathBefore = path.cgPath
        let ptrBefore = Unmanaged.passUnretained(cgPathBefore).toOpaque()
        print("CGPath pointer before: \(ptrBefore)")
        
        _ = UIAccessibility.convertToScreenCoordinates(path, in: view)
        
        let cgPathAfter = path.cgPath
        let ptrAfter = Unmanaged.passUnretained(cgPathAfter).toOpaque()
        print("CGPath pointer after: \(ptrAfter)")
        
        let sameObject = ptrBefore == ptrAfter
        print("Same CGPath object? \(sameObject)")
        
        // Report
        if sameObject {
            XCTAssertTrue(true, "CGPath is same object - mutated in place")
        } else {
            XCTFail("CGPath is DIFFERENT object - replaced, not mutated")
        }
    }
    
    /// Inspect the actual CGPath elements before and after
    func test_inspectCGPathElements() {
        let path = InstrumentedBezierPath()
        path.move(to: CGPoint(x: 5, y: 10))
        path.addLine(to: CGPoint(x: 15, y: 20))
        
        let view = UIView(frame: CGRect(x: 100, y: 200, width: 60, height: 40))
        testView.addSubview(view)
        window.layoutIfNeeded()
        
        let screenOffset = view.convert(CGPoint.zero, to: nil)
        
        func getPoints(from cgPath: CGPath) -> [CGPoint] {
            var points: [CGPoint] = []
            cgPath.applyWithBlock { element in
                switch element.pointee.type {
                case .moveToPoint, .addLineToPoint:
                    points.append(element.pointee.points[0])
                case .addQuadCurveToPoint:
                    points.append(element.pointee.points[0])
                    points.append(element.pointee.points[1])
                case .addCurveToPoint:
                    points.append(element.pointee.points[0])
                    points.append(element.pointee.points[1])
                    points.append(element.pointee.points[2])
                case .closeSubpath:
                    break
                @unknown default:
                    break
                }
            }
            return points
        }
        
        let pointsBefore = getPoints(from: path.cgPath)
        print("Points BEFORE: \(pointsBefore)")
        
        _ = UIAccessibility.convertToScreenCoordinates(path, in: view)
        
        let pointsAfter = getPoints(from: path.cgPath)
        print("Points AFTER: \(pointsAfter)")
        print("Screen offset: \(screenOffset)")
        
        // Check each point was offset
        for i in 0..<min(pointsBefore.count, pointsAfter.count) {
            let deltaX = pointsAfter[i].x - pointsBefore[i].x
            let deltaY = pointsAfter[i].y - pointsBefore[i].y
            
            XCTAssertEqual(deltaX, screenOffset.x, accuracy: 0.1,
                "Point \(i) X delta should equal screenOffset.x (\(screenOffset.x)), got \(deltaX)")
            XCTAssertEqual(deltaY, screenOffset.y, accuracy: 0.1,
                "Point \(i) Y delta should equal screenOffset.y (\(screenOffset.y)), got \(deltaY)")
        }
    }
}

/// Test with a CGMutablePath to see if we can detect the mutation mechanism
final class CGPathMutationTests: XCTestCase {
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
    
    /// Test: Does the API use CGPathCreateCopyByTransformingPath or mutate in place?
    func test_mutationMechanism() {
        let path = UIBezierPath()
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: 10, y: 10))
        
        // Get the underlying mutable path if possible
        let cgPath = path.cgPath
        let isMutable = cgPath is CGMutablePath
        
        print("Is CGPath mutable? \(isMutable)")
        print("CGPath type: \(type(of: cgPath))")
        
        let view = UIView(frame: CGRect(x: 100, y: 200, width: 60, height: 40))
        testView.addSubview(view)
        window.layoutIfNeeded()
        
        // Get pointer before
        let ptrBefore = Unmanaged.passUnretained(cgPath).toOpaque()
        
        _ = UIAccessibility.convertToScreenCoordinates(path, in: view)
        
        // Get pointer after
        let cgPathAfter = path.cgPath
        let ptrAfter = Unmanaged.passUnretained(cgPathAfter).toOpaque()
        
        print("Pointer before: \(ptrBefore)")
        print("Pointer after: \(ptrAfter)")
        print("Same pointer? \(ptrBefore == ptrAfter)")
        
        // If same pointer, the CGPath was mutated in place
        // If different pointer, a new CGPath was created and assigned
        if ptrBefore == ptrAfter {
            // This would indicate mutation happened to the same CGPath object
            // But CGPath is immutable by design... unless they're using private API
            XCTAssertTrue(true, "Same CGPath pointer - internal mutation")
        } else {
            // The UIBezierPath now has a different CGPath
            XCTAssertTrue(true, "Different CGPath pointer - path was replaced")
        }
    }
    
    /// Test: Check if apply() transform method is being called somehow
    func test_checkApplyTransform() {
        class MonitoredPath: UIBezierPath {
            var applyCallCount = 0
            
            override func apply(_ transform: CGAffineTransform) {
                applyCallCount += 1
                print("  [apply() called with transform: \(transform)]")
                super.apply(transform)
            }
        }
        
        let path = MonitoredPath()
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: 10, y: 10))
        
        let view = UIView(frame: CGRect(x: 100, y: 200, width: 60, height: 40))
        testView.addSubview(view)
        window.layoutIfNeeded()
        
        path.applyCallCount = 0
        
        _ = UIAccessibility.convertToScreenCoordinates(path, in: view)
        
        if path.applyCallCount > 0 {
            XCTFail("apply() WAS called \(path.applyCallCount) times!")
        } else {
            XCTAssertTrue(true, "apply() was not called")
        }
    }
    
    /// Test: What if we use an immutable CGPath?
    func test_withImmutableCGPath() {
        // Create an immutable CGPath
        let mutablePath = CGMutablePath()
        mutablePath.move(to: CGPoint(x: 0, y: 0))
        mutablePath.addLine(to: CGPoint(x: 10, y: 10))
        
        // Create immutable copy
        let immutablePath = mutablePath.copy()!
        
        // Create UIBezierPath from immutable CGPath
        let path = UIBezierPath(cgPath: immutablePath)
        
        let view = UIView(frame: CGRect(x: 100, y: 200, width: 60, height: 40))
        testView.addSubview(view)
        window.layoutIfNeeded()
        
        let boundsBefore = path.bounds
        
        _ = UIAccessibility.convertToScreenCoordinates(path, in: view)
        
        let boundsAfter = path.bounds
        
        let mutated = boundsBefore != boundsAfter
        print("Bounds before: \(boundsBefore)")
        print("Bounds after: \(boundsAfter)")
        print("Was mutated? \(mutated)")
        
        if mutated {
            XCTFail("Even with 'immutable' CGPath, the path was mutated!")
        }
    }
    
    /// Test: Direct CGPath mutation check using CGPathApplyWithBlock
    func test_directCGPathMutation() {
        let path = UIBezierPath()
        path.move(to: CGPoint(x: 5, y: 10))
        path.addLine(to: CGPoint(x: 15, y: 20))
        
        // Store original CGPath element points
        var originalPoints: [CGPoint] = []
        path.cgPath.applyWithBlock { element in
            if element.pointee.type == .moveToPoint || element.pointee.type == .addLineToPoint {
                originalPoints.append(element.pointee.points[0])
            }
        }
        
        let view = UIView(frame: CGRect(x: 100, y: 200, width: 60, height: 40))
        testView.addSubview(view)
        window.layoutIfNeeded()
        
        let screenOffset = view.convert(CGPoint.zero, to: nil)
        
        // Call API
        let output = UIAccessibility.convertToScreenCoordinates(path, in: view)
        
        // Check if the ORIGINAL path object's CGPath was mutated
        var mutatedPoints: [CGPoint] = []
        path.cgPath.applyWithBlock { element in
            if element.pointee.type == .moveToPoint || element.pointee.type == .addLineToPoint {
                mutatedPoints.append(element.pointee.points[0])
            }
        }
        
        print("Original points: \(originalPoints)")
        print("After API call: \(mutatedPoints)")
        print("Screen offset: \(screenOffset)")
        
        // Verify mutation
        for i in 0..<originalPoints.count {
            let expectedX = originalPoints[i].x + screenOffset.x
            let expectedY = originalPoints[i].y + screenOffset.y
            
            XCTAssertEqual(mutatedPoints[i].x, expectedX, accuracy: 0.1,
                "Point \(i) X: expected \(expectedX), got \(mutatedPoints[i].x)")
            XCTAssertEqual(mutatedPoints[i].y, expectedY, accuracy: 0.1,
                "Point \(i) Y: expected \(expectedY), got \(mutatedPoints[i].y)")
        }
    }
}
