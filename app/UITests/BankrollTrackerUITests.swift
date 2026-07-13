import XCTest

final class BankrollTrackerUITests: XCTestCase {
    func testLogSessionUpdatesListAndSummary() {
        let app = XCUIApplication()
        app.launch()

        app.staticTexts["Bankroll Tracker"].tap()

        let addButton = app.navigationBars.buttons["Add Session"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 5))
        addButton.tap()

        let nameField = app.textFields["Name"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        nameField.tap()
        nameField.typeText("Sunday Million")

        let buyInField = app.textFields["Buy-in"]
        buyInField.tap()
        buyInField.typeText("100")

        let cashField = app.textFields["Cash-out"]
        cashField.tap()
        cashField.typeText("350")

        app.buttons["Save"].tap()

        let row = app.staticTexts["Sunday Million"]
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        attachScreenshot(of: app, name: "session-logged")

        let rowProfit = app.staticTexts["rowProfit"]
        XCTAssertTrue(rowProfit.exists)
        XCTAssertTrue(rowProfit.label.contains("250"))

        XCTAssertEqual(app.staticTexts["sessionCountValue"].label, "1")
        XCTAssertTrue(app.staticTexts["currentBankrollValue"].label.contains("250"))
    }

    private func attachScreenshot(of app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
