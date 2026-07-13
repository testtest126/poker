import XCTest

final class PreflopRangeUITests: XCTestCase {
    func testGridRendersAndReactsToPositionChange() {
        let app = XCUIApplication()
        app.launch()

        app.staticTexts["Preflop Ranges"].tap()

        let aaCell = app.staticTexts["cell-AA"]
        XCTAssertTrue(aaCell.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["cell-72o"].exists)
        attachScreenshot(of: app, name: "grid-utg")

        let shovePercentageText = app.staticTexts["shovePercentageText"]
        XCTAssertTrue(shovePercentageText.exists)
        let utgPercentage = shovePercentageText.label

        app.buttons["BTN"].tap()

        XCTAssertTrue(shovePercentageText.waitForExistence(timeout: 5))
        XCTAssertNotEqual(shovePercentageText.label, utgPercentage)
        attachScreenshot(of: app, name: "grid-button")
    }

    private func attachScreenshot(of app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
