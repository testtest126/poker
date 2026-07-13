import XCTest

final class LeakAnalysisUITests: XCTestCase {
    func testLeakReportShowsEmptyStateWithoutImportedHands() {
        let app = XCUIApplication()
        app.launch()

        let row = app.staticTexts["Hand History Import & Leaks"]
        for _ in 0..<5 where !row.isHittable {
            app.swipeUp()
        }
        row.tap()

        let leakReportLink = app.staticTexts["View Leak Report"]
        XCTAssertTrue(leakReportLink.waitForExistence(timeout: 5))
        leakReportLink.tap()

        let title = app.navigationBars["Leak Finder"]
        XCTAssertTrue(title.waitForExistence(timeout: 5))

        let emptyState = app.staticTexts["No Hands To Analyze"]
        XCTAssertTrue(emptyState.waitForExistence(timeout: 5))
        attachScreenshot(of: app, name: "leak-finder-empty")
    }

    private func attachScreenshot(of app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
