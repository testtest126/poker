import XCTest

final class PushFoldTrainerUITests: XCTestCase {
    func testPushFoldTrainerDrillFlow() {
        let app = XCUIApplication()
        app.launch()

        app.staticTexts["Push/Fold Trainer"].tap()

        let pushButton = app.buttons["Push"]
        let foldButton = app.buttons["Fold"]
        XCTAssertTrue(pushButton.waitForExistence(timeout: 5))
        XCTAssertTrue(foldButton.exists)
        attachScreenshot(of: app, name: "dealt-spot")

        foldButton.tap()

        let nextHandButton = app.buttons["Next Hand"]
        XCTAssertTrue(nextHandButton.waitForExistence(timeout: 5))
        attachScreenshot(of: app, name: "feedback")
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
