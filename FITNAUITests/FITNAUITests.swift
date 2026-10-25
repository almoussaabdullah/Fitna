import XCTest

/// Smoke tests: the app launches, tabs exist, and a game opens its tutorial.
final class FITNAUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    func testOnboardingAppearsOnFirstLaunch() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting"]
        app.launch()
        XCTAssertTrue(app.staticTexts["أهلًا بك في فِطنة"].waitForExistence(timeout: 10))
    }

    func testTabsAndGameTutorial() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-skipOnboarding"]
        app.launch()
        let gamesTab = app.tabBars.buttons["الألعاب"]
        XCTAssertTrue(gamesTab.waitForExistence(timeout: 10))
        gamesTab.tap()
        let card = app.buttons.containing(NSPredicate(format: "label CONTAINS %@", "حساب البرق")).firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        card.tap()
        XCTAssertTrue(app.buttons["لنبدأ"].waitForExistence(timeout: 5))
        for tab in ["اختبار العقل", "تطوري", "ملفي", "الرئيسية"] {
            if app.buttons["إغلاق"].firstMatch.exists { app.buttons["إغلاق"].firstMatch.tap() }
            XCTAssertTrue(app.tabBars.buttons[tab].waitForExistence(timeout: 5))
            app.tabBars.buttons[tab].tap()
        }
    }
}
