import XCTest

final class DrillsUITests: XCTestCase {
    func testDrillsShowsGeneralPracticeWithoutImportedHandsAndPlaysASpot() {
        let app = XCUIApplication()
        app.launch()

        let row = app.staticTexts["Practice Your Leaks"]
        for _ in 0..<5 where !row.isHittable {
            app.swipeUp()
        }
        row.tap()

        let title = app.navigationBars["Practice Your Leaks"]
        XCTAssertTrue(title.waitForExistence(timeout: 5))

        // No hands imported in a fresh launch, so the drill should clearly say it's
        // falling back to general practice rather than silently pretending to be
        // personalized (or, worse, crashing/showing an empty drill).
        let focusHeader = app.staticTexts["Import hand histories to personalize this drill to your own leaks. Showing general practice for now."]
        XCTAssertTrue(focusHeader.waitForExistence(timeout: 5))
        attachScreenshot(of: app, name: "drills-general-practice")

        let pushButton = app.buttons["Push"]
        let foldButton = app.buttons["Fold"]
        XCTAssertTrue(pushButton.waitForExistence(timeout: 5))
        XCTAssertTrue(foldButton.exists)

        foldButton.tap()

        let nextHandButton = app.buttons["Next Hand"]
        XCTAssertTrue(nextHandButton.waitForExistence(timeout: 5))
        attachScreenshot(of: app, name: "drills-feedback")
        XCTAssertTrue(app.staticTexts["0 / 1 correct"].exists || app.staticTexts["1 / 1 correct"].exists)

        nextHandButton.tap()
        XCTAssertTrue(pushButton.waitForExistence(timeout: 5))
    }

    private func attachScreenshot(of app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
