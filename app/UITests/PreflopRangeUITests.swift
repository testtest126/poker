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
