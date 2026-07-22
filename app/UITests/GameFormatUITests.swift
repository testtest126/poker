import XCTest

final class GameFormatUITests: XCTestCase {
    func testDefaultFormatSeedsRegularMTTDefaults() {
        let app = XCUIApplication()
        app.launch()

        let row = app.staticTexts["Game Format"]
        scrollUntilVisible(row, in: app)
        row.tap()

        let stackValue = app.staticTexts["gameFormatStackValue"]
        scrollUntilVisible(stackValue, in: app)
        XCTAssertTrue(stackValue.waitForExistence(timeout: 5))
        XCTAssertEqual(stackValue.label, "100 bb", "Regular MTT should default to a 100bb seeded stack")

        let bountyToggle = app.switches["gameFormatBountyToggle"]
        XCTAssertTrue(bountyToggle.exists)
        XCTAssertEqual(bountyToggle.value as? String, "0", "Regular MTT shouldn't default the bounty overlay on")

        attachScreenshot(of: app, name: "format-regular-default")
    }

    func testSelectingPKOSeedsBountyOnAndAShorterICMEmphasis() {
        let app = XCUIApplication()
        app.launch()

        let row = app.staticTexts["Game Format"]
        scrollUntilVisible(row, in: app)
        row.tap()

        let picker = app.buttons["gameFormatPicker"]
        scrollUntilVisible(picker, in: app)
        XCTAssertTrue(picker.waitForExistence(timeout: 5))
        picker.tap()

        let pkoOption = app.buttons["PKO (Bounty)"]
        XCTAssertTrue(pkoOption.waitForExistence(timeout: 5))
        pkoOption.tap()

        let bountyToggle = app.switches["gameFormatBountyToggle"]
        scrollUntilVisible(bountyToggle, in: app)
        XCTAssertEqual(bountyToggle.value as? String, "1", "Selecting PKO should seed the bounty toggle on")

        let bountyValue = app.staticTexts["gameFormatBountyValue"]
        scrollUntilVisible(bountyValue, in: app)
        XCTAssertTrue(bountyValue.waitForExistence(timeout: 5))
        XCTAssertEqual(bountyValue.label, "33%", "PKO's default bounty should be 33% of the starting stack")

        attachScreenshot(of: app, name: "format-pko-seeded")
    }

    func testSelectingCashDisablesICMAndBounty() {
        let app = XCUIApplication()
        app.launch()

        let row = app.staticTexts["Game Format"]
        scrollUntilVisible(row, in: app)
        row.tap()

        let picker = app.buttons["gameFormatPicker"]
        scrollUntilVisible(picker, in: app)
        XCTAssertTrue(picker.waitForExistence(timeout: 5))
        picker.tap()

        let cashOption = app.buttons["Cash Game"]
        XCTAssertTrue(cashOption.waitForExistence(timeout: 5))
        cashOption.tap()

        let icmToggle = app.switches["gameFormatICMToggle"]
        scrollUntilVisible(icmToggle, in: app)
        XCTAssertEqual(icmToggle.value as? String, "0", "Cash should seed ICM-awareness off")

        let bountyToggle = app.switches["gameFormatBountyToggle"]
        XCTAssertEqual(bountyToggle.value as? String, "0", "Cash should seed the bounty overlay off")

        // Speed row shouldn't render at all for cash (blind levels don't apply).
        XCTAssertFalse(app.staticTexts["gameFormatSpeedText"].exists)

        attachScreenshot(of: app, name: "format-cash-seeded")
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
