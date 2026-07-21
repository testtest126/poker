import XCTest

final class EquityCalculatorUITests: XCTestCase {
    func testDefaultHandsCalculatePreflopEquity() {
        let app = XCUIApplication()
        app.launch()

        app.staticTexts["Equity Calculator"].tap()

        let calculateButton = app.buttons["calculateButton"]
        XCTAssertTrue(calculateButton.waitForExistence(timeout: 5))
        XCTAssertTrue(calculateButton.isEnabled, "Default hero/villain (AKs vs QQ) should already be a valid, calculable setup")

        calculateButton.tap()

        // The Result section renders below the fold on a short screen — Form/List lazily
        // instantiates rows, so its content isn't in the accessibility tree (and can't be
        // found by waitForExistence) until scrolled into view.
        let heroWinRate = app.staticTexts["heroWinRate"]
        scrollUntilVisible(heroWinRate, in: app)
        XCTAssertTrue(heroWinRate.waitForExistence(timeout: 20))
        attachScreenshot(of: app, name: "preflop-result")

        // Read the percentage now, before scrolling further — once scrolled past, a Form
        // row can be recycled/deallocated, and re-reading `.label` on a stale reference
        // isn't reliable.
        let heroPercent = Double(heroWinRate.label.replacingOccurrences(of: "%", with: "")) ?? -1

        let tieRate = app.staticTexts["tieRate"]
        let villainWinRate = app.staticTexts["villainWinRate"]
        let equityMethodText = app.staticTexts["equityMethodText"]
        scrollUntilVisible(equityMethodText, in: app)
        XCTAssertTrue(tieRate.exists)
        XCTAssertTrue(villainWinRate.exists)
        XCTAssertTrue(equityMethodText.exists)

        // AKs vs QQ is close to a coinflip, not a blowout in either direction.
        XCTAssertTrue(heroPercent > 30 && heroPercent < 60, "AKs vs QQ should be roughly 30-60%, got \(heroPercent)%")
    }

    func testInvalidHandDisablesCalculate() {
        let app = XCUIApplication()
        app.launch()

        app.staticTexts["Equity Calculator"].tap()

        let heroField = app.textFields["heroNotationField"]
        XCTAssertTrue(heroField.waitForExistence(timeout: 5))
        heroField.tap()
        heroField.clearText()
        heroField.typeText("XYZ")

        let calculateButton = app.buttons["calculateButton"]
        XCTAssertFalse(calculateButton.isEnabled, "An invalid hand notation should disable Calculate")
    }

    func testFlopBoardRequiresAllThreeCardsBeforeCalculating() {
        let app = XCUIApplication()
        app.launch()

        app.staticTexts["Equity Calculator"].tap()

        app.buttons["Flop"].tap()

        // Adding the 3 flop card rows pushes Calculate below the fold — same lazy-rendering
        // situation as the Result section above.
        let calculateButton = app.buttons["calculateButton"]
        scrollUntilVisible(calculateButton, in: app)
        XCTAssertTrue(calculateButton.waitForExistence(timeout: 5))
        XCTAssertFalse(calculateButton.isEnabled, "An unset flop should block calculation")
    }

    /// Swipes up on `app` until `element` shows up in the accessibility tree (or gives up
    /// after a bounded number of attempts) — SwiftUI's `Form`/`List` only instantiate rows
    /// near the current viewport, so anything below the fold doesn't exist as far as
    /// XCUITest is concerned until it's been scrolled to.
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

extension XCUIElement {
    func clearText() {
        guard let stringValue = value as? String, !stringValue.isEmpty else { return }
        let deleteString = String(repeating: XCUIKeyboardKey.delete.rawValue, count: stringValue.count)
        typeText(deleteString)
    }
}
