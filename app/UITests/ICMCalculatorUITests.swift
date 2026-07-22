import XCTest

final class ICMCalculatorUITests: XCTestCase {
    func testDefaultStacksProduceICMEquitySummingToThePrizePool() {
        let app = XCUIApplication()
        app.launch()

        let icmRow = app.staticTexts["ICM Calculator"]
        scrollUntilVisible(icmRow, in: app)
        icmRow.tap()

        // Defaults: stacks 5000/3000/2000, payouts 500/300/200 — a $1000 pool, so the total
        // equity row should read exactly $1000.00 (the same worked example ai-docs/ICM.md
        // hand-derives).
        let total = app.staticTexts["icmTotalEquity"]
        scrollUntilVisible(total, in: app)
        XCTAssertTrue(total.waitForExistence(timeout: 5))
        XCTAssertEqual(total.label, "$1000.00")

        let caveat = app.staticTexts["icmCaveatText"]
        XCTAssertTrue(caveat.exists)
        XCTAssertTrue(caveat.label.contains("ICM.md"))
        attachScreenshot(of: app, name: "icm-default")
    }

    func testAddingAPlayerAddsAStackRow() {
        let app = XCUIApplication()
        app.launch()

        let icmRow = app.staticTexts["ICM Calculator"]
        scrollUntilVisible(icmRow, in: app)
        icmRow.tap()

        let addPlayerButton = app.buttons["addPlayerButton"]
        scrollUntilVisible(addPlayerButton, in: app)
        XCTAssertTrue(addPlayerButton.waitForExistence(timeout: 5))
        addPlayerButton.tap()

        let newStackField = app.textFields["stackField-Seat 4"]
        scrollUntilVisible(newStackField, in: app)
        XCTAssertTrue(newStackField.waitForExistence(timeout: 5), "Adding a player should add a 4th stack row")
    }

    func testInvalidStackShowsValidationMessageInsteadOfEquity() {
        let app = XCUIApplication()
        app.launch()

        let icmRow = app.staticTexts["ICM Calculator"]
        scrollUntilVisible(icmRow, in: app)
        icmRow.tap()

        let firstStackField = app.textFields["stackField-Seat 1"]
        scrollUntilVisible(firstStackField, in: app)
        XCTAssertTrue(firstStackField.waitForExistence(timeout: 5))
        firstStackField.tap()
        // Appending a non-numeric character (rather than deleting the existing text) is a
        // more reliable way to invalidate a `.numberPad` field in XCUITest — the delete key
        // synthesis `clearText()` (used elsewhere for a plain text field) doesn't reliably
        // land on a number-pad keyboard's layout.
        firstStackField.typeText("x")

        let validationText = app.staticTexts["icmValidationText"]
        scrollUntilVisible(validationText, in: app)
        XCTAssertTrue(validationText.waitForExistence(timeout: 5), "An empty/invalid stack should show a validation message instead of an equity result")
        XCTAssertFalse(app.staticTexts["icmTotalEquity"].exists)
        attachScreenshot(of: app, name: "icm-invalid-stack")
    }

    private func scrollUntilVisible(_ element: XCUIElement, in app: XCUIApplication, maxSwipes: Int = 8) {
        for _ in 0..<maxSwipes {
            if element.exists { return }
            app.swipeUp()
        }
    }

    private func attachScreenshot(of app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
