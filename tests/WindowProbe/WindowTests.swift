import XCTest
import UIKit
import AVFoundation

final class WindowTests: XCTestCase {
    func testOrdinaryWindowPortraitLandscapePortrait() throws {
        XCTAssertEqual(UIDevice.current.userInterfaceIdiom, .pad)
        XCUIDevice.shared.orientation = .landscapeLeft
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let initialDisplay = springboard.frame.size
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.buttons["runWindowTests"].waitForExistence(timeout: 15))
        let initialImage = XCUIScreen.main.screenshot().image
        let window = app.windows.firstMatch
        if abs(window.frame.width - initialDisplay.width) < 1 && abs(window.frame.height - initialDisplay.height) < 1 {
            window.coordinate(withNormalizedOffset: CGVector(dx: 1, dy: 1))
                .withOffset(CGVector(dx: -16, dy: -16)).press(forDuration: 0.3,
                    thenDragTo: window.coordinate(withNormalizedOffset: CGVector(dx: 0.68, dy: 0.78)))
        }
        app.buttons["runWindowTests"].tap()
        var measurements: [[String: Any]] = []
        var firstSize = CGSize.zero
        for phase in 0..<3 {
            let next = app.buttons[phase < 2 ? "windowPhaseReady\(phase)" : "windowReportReady"]
            guard next.waitForExistence(timeout: 75) else { XCTFail("Window phase did not finish"); break }
            let frame = window.frame
            let display = springboard.frame.size
            let video = phase == 1 ? CGSize(width: 1080, height: 498) : CGSize(width: 1080, height: 2340)
            let picture = AVMakeRect(aspectRatio: video, insideRect: frame)
            let gap = max(frame.width - picture.width, frame.height - picture.height) / 2
            let windowed = abs(frame.width - display.width) > 1 || abs(frame.height - display.height) > 1
            let screenshot = XCUIScreen.main.screenshot()
            let image = screenshot.image
            let desktopStable = image.size == initialImage.size && image.imageOrientation == initialImage.imageOrientation
            if phase == 0 { firstSize = frame.size }
            let expected = phase == 1 ? CGSize(width: firstSize.height, height: firstSize.width) : firstSize
            let swapError = max(abs(frame.width - expected.width), abs(frame.height - expected.height))
            let attachment = XCTAttachment(screenshot: screenshot)
            attachment.name = "Window phase \(phase)"
            attachment.lifetime = .keepAlways
            add(attachment)
            let corner = window.coordinate(withNormalizedOffset: CGVector(dx: 1, dy: 1))
                .withOffset(CGVector(dx: -16, dy: -16))
            corner.press(forDuration: 0.3,
                thenDragTo: window.coordinate(withNormalizedOffset: CGVector(dx: 0.78, dy: 0.78)))
            Thread.sleep(forTimeInterval: 3)
            let resized = window.frame.size
            let resizeError = max(abs(resized.width - frame.width), abs(resized.height - frame.height))
            let passed = windowed && desktopStable && gap <= 1 && swapError <= 1 && resizeError <= 1
            measurements.append([
                "phase": phase, "window": [frame.width, frame.height],
                "display": [display.width, display.height], "windowed": windowed,
                "desktopStable": desktopStable, "edgeGap": gap, "swapError": swapError,
                "afterShrink": [resized.width, resized.height], "resizeError": resizeError, "passed": passed
            ])
            XCTAssertTrue(passed, "Outside window failed: \(measurements.last!)")
            if phase < 2 { next.tap() }
        }
        let report = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("window-external-report.json")
        try JSONSerialization.data(withJSONObject: measurements, options: [.prettyPrinted, .sortedKeys])
            .write(to: report, options: .atomic)
    }
}
