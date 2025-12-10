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

/// Tests demonstrating that view transforms correctly affect the output path
final class TransformOutputTests: XCTestCase {
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

    /// Scale transform correctly doubles the output path size
    func test_scaleTransformChangesSize() {
        // Each view gets its OWN path to avoid mutation bug
        func makePath() -> UIBezierPath {
            let path = UIBezierPath()
            path.move(to: CGPoint(x: 0, y: 0))
            path.addLine(to: CGPoint(x: 50, y: 30))
            return path
        }

        // Plain view - no transform
        let plainView = PathView(frame: CGRect(x: 100, y: 100, width: 60, height: 40))
        plainView.relativePath = makePath()
        testView.addSubview(plainView)

        // View with 2x scale
        let scaledView = PathView(frame: CGRect(x: 100, y: 100, width: 60, height: 40))
        scaledView.transform = CGAffineTransform(scaleX: 2, y: 2)
        scaledView.relativePath = makePath()
        testView.addSubview(scaledView)

        window.layoutIfNeeded()

        let plainOutput = plainView.accessibilityPath!
        let scaledOutput = scaledView.accessibilityPath!

        // Scale 2x should double the size of the path
        XCTAssertEqual(scaledOutput.bounds.width, plainOutput.bounds.width * 2, accuracy: 1.0,
            "Scale 2x should double width")
        XCTAssertEqual(scaledOutput.bounds.height, plainOutput.bounds.height * 2, accuracy: 1.0,
            "Scale 2x should double height")
    }

    /// Translation transform correctly shifts the output path origin
    func test_translationTransformShiftsOrigin() {
        func makePath() -> UIBezierPath {
            let path = UIBezierPath()
            path.move(to: CGPoint(x: 0, y: 0))
            path.addLine(to: CGPoint(x: 50, y: 30))
            return path
        }

        let plainView = PathView(frame: CGRect(x: 100, y: 100, width: 60, height: 40))
        plainView.relativePath = makePath()
        testView.addSubview(plainView)

        let translatedView = PathView(frame: CGRect(x: 100, y: 100, width: 60, height: 40))
        translatedView.transform = CGAffineTransform(translationX: 50, y: 50)
        translatedView.relativePath = makePath()
        testView.addSubview(translatedView)

        window.layoutIfNeeded()

        let plainOutput = plainView.accessibilityPath!
        let translatedOutput = translatedView.accessibilityPath!

        let xDiff = translatedOutput.bounds.origin.x - plainOutput.bounds.origin.x
        let yDiff = translatedOutput.bounds.origin.y - plainOutput.bounds.origin.y

        XCTAssertEqual(xDiff, 50, accuracy: 1.0, "Translation +50x should shift X by 50")
        XCTAssertEqual(yDiff, 50, accuracy: 1.0, "Translation +50y should shift Y by 50")
    }

    /// Rotation transform changes the bounding box shape
    func test_rotationTransformChangesBounds() {
        func makePath() -> UIBezierPath {
            let path = UIBezierPath()
            path.move(to: CGPoint(x: 0, y: 0))
            path.addLine(to: CGPoint(x: 50, y: 0))  // Horizontal line
            return path
        }

        let plainView = PathView(frame: CGRect(x: 100, y: 100, width: 60, height: 40))
        plainView.relativePath = makePath()
        testView.addSubview(plainView)

        // Rotate 90 degrees - horizontal line becomes vertical
        let rotatedView = PathView(frame: CGRect(x: 100, y: 100, width: 60, height: 40))
        rotatedView.transform = CGAffineTransform(rotationAngle: .pi / 2)
        rotatedView.relativePath = makePath()
        testView.addSubview(rotatedView)

        window.layoutIfNeeded()

        let plainOutput = plainView.accessibilityPath!
        let rotatedOutput = rotatedView.accessibilityPath!

        // Plain: horizontal line has width but near-zero height
        // Rotated 90°: vertical line has height but near-zero width
        XCTAssertGreaterThan(plainOutput.bounds.width, plainOutput.bounds.height,
            "Plain horizontal line should be wider than tall")
        XCTAssertGreaterThan(rotatedOutput.bounds.height, rotatedOutput.bounds.width,
            "Rotated 90° should make the line taller than wide")
    }
}
