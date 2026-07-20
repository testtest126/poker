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

    func testBountyOverlayWidensRangeAndTogglesCaveat() {
        let app = XCUIApplication()
        app.launch()

        app.staticTexts["Preflop Ranges"].tap()

        let aaCell = app.staticTexts["cell-AA"]
        XCTAssertTrue(aaCell.waitForExistence(timeout: 5))

        let summaryText = app.staticTexts["shovePercentageText"]
        let baseSummary = summaryText.label
        XCTAssertFalse(baseSummary.contains("with bounty"))

        app.switches["bountyToggle"].tap()

        let bountySlider = app.sliders["bountySlider"]
        XCTAssertTrue(bountySlider.waitForExistence(timeout: 5))
        attachScreenshot(of: app, name: "bounty-off-default-size")

        // Drag the bounty slider toward its high end to get a meaningfully wide bounty.
        bountySlider.adjust(toNormalizedSliderPosition: 0.9)

        XCTAssertTrue(summaryText.waitForExistence(timeout: 5))
        XCTAssertTrue(summaryText.label.contains("with bounty"), "Summary should show both the base and bounty-widened percentage")

        let caveat = app.staticTexts["bountyCaveatText"]
        XCTAssertTrue(caveat.waitForExistence(timeout: 5))
        XCTAssertTrue(caveat.label.contains("BOUNTY.md"))
        attachScreenshot(of: app, name: "bounty-on-covering-villain")

        // Flip "You cover villain" off — the bounty should stop being collectible, and the
        // caveat text should say so explicitly instead of describing a widened range.
        app.switches["heroCoversVillainToggle"].tap()

        XCTAssertTrue(caveat.waitForExistence(timeout: 5))
        XCTAssertTrue(caveat.label.contains("isn't collectible"))
        attachScreenshot(of: app, name: "bounty-on-not-covering-villain")
    }

    private func attachScreenshot(of app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
