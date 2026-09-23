import XCTest

final class ShellUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testFirstLaunchShowsJobBoardWithoutBlockingOnboarding() {
        let app = XCUIApplication()
        app.launchArguments += [
            "-AppleLanguages", "(en)",
            "-shell.onboarding.complete", "NO",
            "-shell.legal.acceptedVersion", "",
        ]
        app.launch()
        XCTAssertTrue(app.navigationBars["Jobs"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Enter new job"].exists)
    }

    func testSettingsKeepsLegalLinksAvailable() {
        let app = XCUIApplication()
        app.launchArguments += [
            "-AppleLanguages", "(en)",
            "-shell.onboarding.complete", "YES",
            "-shell.legal.acceptedVersion", "1",
        ]
        app.launch()

        app.buttons["shell.settings"].tap()
        // StoreKit catalog can be unavailable on a simulator without the
        // production products; legal links remain reachable regardless.
        XCTAssertTrue(app.buttons["Privacy Policy"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Terms of Use"].exists)
    }

    func testSettingsOpensWithoutTerminatingApp() {
        let app = launchPastOnboarding()
        let settings = app.buttons["shell.settings"]
        XCTAssertTrue(settings.waitForExistence(timeout: 5))
        settings.tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.state, .runningForeground)
    }

    func testEveryTabHasVisibleIcon() {
        let app = launchPastOnboarding()
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 5))
        let tabs = tabBar.buttons.allElementsBoundByIndex
        XCTAssertFalse(tabs.isEmpty)
        for tab in tabs {
            XCTAssertGreaterThan(tab.descendants(matching: .image).count, 0, "Missing icon for tab: \(tab.label)")
        }
    }

    /// Run this same suite through the documented destination matrix. The source
    /// remains device-agnostic; CI destinations select compact iPhone and iPad.
    func testPrimaryControlsMeetMinimumHitTarget() {
        let app = launchPastOnboarding()
        let button = app.buttons["Enter new job"]
        XCTAssertTrue(button.waitForExistence(timeout: 5))
        let frame = button.frame
        XCTAssertGreaterThanOrEqual(frame.height, 44)
        XCTAssertGreaterThanOrEqual(frame.width, 44)
    }

    private func launchPastOnboarding() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += [
            "-AppleLanguages", "(en)",
            "-shell.onboarding.complete", "YES",
            "-shell.legal.acceptedVersion", "1",
        ]
        app.launch()
        return app
    }
}
