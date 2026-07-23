import XCTest

final class OmahaEquityCalculatorUITests: XCTestCase {
    func testDefaultHandsCalculatePreflopEquity() {
        let app = XCUIApplication()
        app.launch()

        let row = app.staticTexts["Omaha Equity (Beta)"]
        scrollUntilVisible(row, in: app)
        row.tap()

        let calculateButton = app.buttons["omahaCalculateButton"]
        scrollUntilVisible(calculateButton, in: app)
        XCTAssertTrue(calculateButton.waitForExistence(timeout: 5))
        XCTAssertTrue(calculateButton.isEnabled, "Default hero/villain (AAKKds vs 8765ds) should already be a valid, calculable setup")

        calculateButton.tap()

        let heroWinRate = app.staticTexts["omahaHeroWinRate"]
        scrollUntilVisible(heroWinRate, in: app)
        XCTAssertTrue(heroWinRate.waitForExistence(timeout: 30))
        attachScreenshot(of: app, name: "omaha-preflop-result")

        let heroPercent = Double(heroWinRate.label.replacingOccurrences(of: "%", with: "")) ?? -1

        let tieRate = app.staticTexts["omahaTieRate"]
        let villainWinRate = app.staticTexts["omahaVillainWinRate"]
        let methodText = app.staticTexts["omahaEquityMethodText"]
        scrollUntilVisible(methodText, in: app)
        XCTAssertTrue(tieRate.exists)
        XCTAssertTrue(villainWinRate.exists)
        XCTAssertTrue(methodText.exists)
        XCTAssertTrue(methodText.label.contains("Monte Carlo"))

        // AAKKds vs 8765ds is a modest favorite (~60%, "only a 3-2 favorite" — see
        // ai-docs/OMAHA.md), not a coinflip or a blowout.
        XCTAssertTrue(heroPercent > 45 && heroPercent < 75, "AAKKds vs 8765ds should be a modest favorite, got \(heroPercent)%")
    }

    func testInvalidHandDisablesCalculate() {
        let app = XCUIApplication()
        app.launch()

        let row = app.staticTexts["Omaha Equity (Beta)"]
        scrollUntilVisible(row, in: app)
        row.tap()

        let heroField = app.textFields["omahaHeroNotationField"]
        XCTAssertTrue(heroField.waitForExistence(timeout: 5))
        heroField.tap()
        heroField.typeText("x")

        let calculateButton = app.buttons["omahaCalculateButton"]
        scrollUntilVisible(calculateButton, in: app)
        XCTAssertFalse(calculateButton.isEnabled, "An invalid hand notation should disable Calculate")

        let validationText = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'valid 4-card hand'")).firstMatch
        XCTAssertTrue(validationText.exists)
    }

    func testFlopBoardRequiresAllThreeCardsBeforeCalculating() {
        let app = XCUIApplication()
        app.launch()

        let row = app.staticTexts["Omaha Equity (Beta)"]
        scrollUntilVisible(row, in: app)
        row.tap()

        app.buttons["Flop"].tap()

        let calculateButton = app.buttons["omahaCalculateButton"]
        scrollUntilVisible(calculateButton, in: app)
        XCTAssertTrue(calculateButton.waitForExistence(timeout: 5))
        XCTAssertFalse(calculateButton.isEnabled, "An unset flop should block calculation")
    }

    func testPreciseModeDisabledPreflopEnabledOnceBoardIsSet() {
        let app = XCUIApplication()
        app.launch()

        let row = app.staticTexts["Omaha Equity (Beta)"]
        scrollUntilVisible(row, in: app)
        row.tap()

        let modePicker = app.segmentedControls["omahaEquityModePicker"]
        XCTAssertTrue(modePicker.waitForExistence(timeout: 5))
        XCTAssertFalse(modePicker.isEnabled, "Precise mode requires a board — should be disabled preflop")

        app.buttons["Flop"].tap()

        scrollUntilVisible(modePicker, in: app)
        XCTAssertTrue(modePicker.isEnabled, "Precise mode should be available once the street isn't Preflop")

        app.buttons["Preflop"].tap()
        XCTAssertFalse(modePicker.isEnabled)
    }

    func testPreciseModeProducesAnExactResultOnAGivenRiver() {
        // Deliberately a *river*-given board (all 5 cards known), not a flop — a flop-given
        // exact Omaha calculation still needs to enumerate C(41,2) = 820 board completions
        // at 120 evaluations each, which measured close to (and, on one run, over) a 30s
        // timeout on this simulator's debug build. A river-given board needs zero
        // completions (a single, instant evaluation) — this test exists to prove Precise
        // mode correctly reaches the exact code path, not to benchmark flop-exact's on-device
        // timing (see ai-docs/OMAHA.md's performance note).
        let app = XCUIApplication()
        app.launch()

        let row = app.staticTexts["Omaha Equity (Beta)"]
        scrollUntilVisible(row, in: app)
        row.tap()

        app.buttons["River"].tap()

        let boardField = app.textFields["omahaBoardNotationField"]
        scrollUntilVisible(boardField, in: app)
        XCTAssertTrue(boardField.waitForExistence(timeout: 5))
        boardField.tap()
        boardField.typeText("2c9d4hTsJc")
        // Dismiss the keyboard (typing a newline resigns a single-line TextField's first
        // responder) before interacting with anything below it. Without this, a later tap on
        // "Calculate" computed its coordinates for the button's expected position but
        // actually landed on the still-open keyboard underneath it — confirmed by debugging:
        // the board field's value gained a stray trailing "Y" (the keyboard key at that
        // screen position), corrupting the board notation and leaving Calculate never really
        // tapped. A plain `app.navigationBars.firstMatch.tap()` was tried first and did not
        // reliably dismiss the keyboard either.
        boardField.typeText("\n")

        let modePicker = app.segmentedControls["omahaEquityModePicker"]
        scrollUntilVisible(modePicker, in: app)
        XCTAssertTrue(modePicker.isEnabled)
        modePicker.buttons["Precise"].tap()

        let calculateButton = app.buttons["omahaCalculateButton"]
        scrollUntilVisible(calculateButton, in: app)
        XCTAssertTrue(calculateButton.isEnabled)
        calculateButton.tap()

        let methodText = app.staticTexts["omahaEquityMethodText"]
        scrollUntilVisible(methodText, in: app)
        XCTAssertTrue(methodText.waitForExistence(timeout: 15))
        XCTAssertTrue(methodText.label.contains("Exact"), "Precise mode's caption should say Exact, got: \(methodText.label)")
        attachScreenshot(of: app, name: "omaha-precise-flop-result")
    }

    /// Interleaves swiping with waiting (rather than swiping a fixed number of times up
    /// front and only then waiting statically) — after tapping Calculate, the Result section
    /// doesn't exist in the accessibility tree at all until the async computation finishes
    /// *and* it's scrolled into view. A fixed burst of swipes immediately after the tap can
    /// exhaust itself before the computation completes, leaving a `waitForExistence` polling
    /// a scroll position the still-to-appear content will never reach.
    private func scrollUntilVisible(_ element: XCUIElement, in app: XCUIApplication, timeout: TimeInterval = 30) {
        let deadline = Date().addingTimeInterval(timeout)
        while !element.exists && Date() < deadline {
            app.swipeUp()
            Thread.sleep(forTimeInterval: 0.5)
        }
    }

    private func attachScreenshot(of app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
