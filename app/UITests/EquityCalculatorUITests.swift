import XCTest

final class EquityCalculatorUITests: XCTestCase {
    func testDefaultHandsCalculatePreflopEquity() {
        let app = XCUIApplication()
        app.launch()

        app.staticTexts["Equity Calculator"].tap()

        let calculateButton = app.buttons["calculateButton"]
        scrollUntilVisible(calculateButton, in: app)
        XCTAssertTrue(calculateButton.waitForExistence(timeout: 5))
        XCTAssertTrue(calculateButton.isEnabled, "Default hero/villain (AKs vs QQ) should already be a valid, calculable setup")

        calculateButton.tap()

        // The Result section renders below the fold on a short screen — Form/List lazily
        // instantiates rows, so its content isn't in the accessibility tree (and can't be
        // found by waitForExistence) until scrolled into view.
        let heroWinRate = app.staticTexts["heroWinRate"]
        scrollUntilVisible(heroWinRate, in: app)
        XCTAssertTrue(heroWinRate.waitForExistence(timeout: 40))
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
        scrollUntilVisible(calculateButton, in: app)
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

    func testPreciseModeDisabledPreflopEnabledOnceBoardIsSet() {
        let app = XCUIApplication()
        app.launch()

        app.staticTexts["Equity Calculator"].tap()

        let modePicker = app.segmentedControls["equityModePicker"]
        XCTAssertTrue(modePicker.waitForExistence(timeout: 5))
        XCTAssertFalse(modePicker.isEnabled, "Precise mode requires a board — should be disabled preflop")

        app.buttons["Flop"].tap()

        scrollUntilVisible(modePicker, in: app)
        XCTAssertTrue(modePicker.isEnabled, "Precise mode should be available once the street isn't Preflop")

        // Switching back to Preflop should fall back to Fast automatically rather than
        // leaving Precise selected but unreachable.
        app.buttons["Preflop"].tap()
        XCTAssertFalse(modePicker.isEnabled)
    }

    func testPreciseModeProducesAnExactResultOnAFlop() {
        let app = XCUIApplication()
        app.launch()

        app.staticTexts["Equity Calculator"].tap()

        app.buttons["Flop"].tap()
        // The rank menu doesn't fit all 13 ranks on screen at once and isn't scrolled
        // automatically, so only ranks from its initially-visible set (A,K,Q,J,T,9-5) are
        // safe to pick here without adding menu-scrolling logic too.
        setBoardCard(index: 1, rank: "8", suit: "♣", in: app)
        setBoardCard(index: 2, rank: "7", suit: "♦", in: app)
        setBoardCard(index: 3, rank: "9", suit: "♥", in: app)

        let modePicker = app.segmentedControls["equityModePicker"]
        scrollUntilVisible(modePicker, in: app)
        XCTAssertTrue(modePicker.isEnabled)
        modePicker.buttons["Precise"].tap()

        let calculateButton = app.buttons["calculateButton"]
        scrollUntilVisible(calculateButton, in: app)
        XCTAssertTrue(calculateButton.isEnabled)
        calculateButton.tap()

        let equityMethodText = app.staticTexts["equityMethodText"]
        scrollUntilVisible(equityMethodText, in: app)
        XCTAssertTrue(equityMethodText.waitForExistence(timeout: 40))
        XCTAssertTrue(equityMethodText.label.contains("Exact"), "Precise mode's caption should say Exact, got: \(equityMethodText.label)")
        attachScreenshot(of: app, name: "precise-flop-result")
    }

    private func setBoardCard(index: Int, rank: String, suit: String, in app: XCUIApplication) {
        let label = "Card \(index)"

        let rankPicker = app.buttons["\(label)RankPicker"]
        scrollUntilVisible(rankPicker, in: app)
        tapWhenHittable(rankPicker)
        let rankOption = app.buttons[rank]
        XCTAssertTrue(rankOption.waitForExistence(timeout: 3), "Rank menu option \(rank) never appeared")
        rankOption.tap()

        let suitPicker = app.buttons["\(label)SuitPicker"]
        scrollUntilVisible(suitPicker, in: app)
        tapWhenHittable(suitPicker)
        let suitOption = app.buttons[suit]
        XCTAssertTrue(suitOption.waitForExistence(timeout: 3), "Suit menu option \(suit) never appeared")
        suitOption.tap()
    }

    /// Taps `element` once it's actually hittable, not just present in the accessibility
    /// tree — right after a Form row changes (e.g. a menu closing and the next row's layout
    /// settling), a `.tap()` on an element that technically "exists" can compute an invalid
    /// off-screen hit point and silently miss, leaving the menu it should have opened never
    /// actually opened.
    private func tapWhenHittable(_ element: XCUIElement, timeout: TimeInterval = 3) {
        let deadline = Date().addingTimeInterval(timeout)
        while !element.isHittable && Date() < deadline {
            Thread.sleep(forTimeInterval: 0.2)
        }
        element.tap()
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
