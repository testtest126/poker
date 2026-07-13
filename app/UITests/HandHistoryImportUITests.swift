import XCTest

final class HandHistoryImportUITests: XCTestCase {
    func testImportScreenShowsPrivacyNoteToolbarAndEmptyState() {
        let app = XCUIApplication()
        app.launch()

        let row = app.staticTexts["Hand History Import & Leaks"]
        for _ in 0..<5 where !row.isHittable {
            app.swipeUp()
        }
        row.tap()

        let importButton = app.navigationBars.buttons["Import"]
        XCTAssertTrue(importButton.waitForExistence(timeout: 5))

        let privacyText = app.staticTexts["Parsed entirely on this device. Nothing is uploaded or leaves your phone."]
        XCTAssertTrue(privacyText.waitForExistence(timeout: 5))

        let emptyState = app.staticTexts["No Hands Imported"]
        XCTAssertTrue(emptyState.waitForExistence(timeout: 5))
        attachScreenshot(of: app, name: "hand-history-import-empty")
    }

    private func attachScreenshot(of app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
