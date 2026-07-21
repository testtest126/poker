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

    func testFacingShoveModeRendersAndReactsToOpponentChange() {
        let app = XCUIApplication()
        app.launch()

        app.staticTexts["Preflop Ranges"].tap()

        app.buttons["Facing Shove"].tap()

        let aaCell = app.staticTexts["cell-AA"]
        XCTAssertTrue(aaCell.waitForExistence(timeout: 5))
        attachScreenshot(of: app, name: "facing-shove-utg")

        let summaryText = app.staticTexts["shovePercentageText"]
        XCTAssertTrue(summaryText.exists)
        let utgSummary = summaryText.label

        // Both the opponent and hero pickers can show overlapping position labels (e.g.
        // both may offer "BTN"), so scope the tap to the opponent picker specifically.
        let opponentPicker = app.segmentedControls["opponentPositionPicker"]
        XCTAssertTrue(opponentPicker.waitForExistence(timeout: 5))
        opponentPicker.buttons["BTN"].tap()

        XCTAssertTrue(summaryText.waitForExistence(timeout: 5))
        XCTAssertNotEqual(summaryText.label, utgSummary)
        attachScreenshot(of: app, name: "facing-shove-button")
    }

    func testFacingOpenModeRendersAndReactsToHeroChange() {
        let app = XCUIApplication()
        app.launch()

        app.staticTexts["Preflop Ranges"].tap()

        app.buttons["Facing Open"].tap()

        let aaCell = app.staticTexts["cell-AA"]
        XCTAssertTrue(aaCell.waitForExistence(timeout: 5))
        attachScreenshot(of: app, name: "facing-open-bb")

        let summaryText = app.staticTexts["shovePercentageText"]
        XCTAssertTrue(summaryText.exists)
        let bbSummary = summaryText.label

        // Hero picker defaults to BB (always valid); switch to SB — should defend
        // narrower, so the summary text should change. Scoped to the hero picker since
        // "SB" also appears in the opponent picker.
        let heroPicker = app.segmentedControls["heroPositionPicker"]
        XCTAssertTrue(heroPicker.waitForExistence(timeout: 5))
        heroPicker.buttons["SB"].tap()

        XCTAssertTrue(summaryText.waitForExistence(timeout: 5))
        XCTAssertNotEqual(summaryText.label, bbSummary)
        attachScreenshot(of: app, name: "facing-open-sb")
    }

    private func attachScreenshot(of app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
