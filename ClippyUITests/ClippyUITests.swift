//
//  ClippyUITests.swift
//  ClippyUITests
//
//  Created by Jnani Smart on 22/03/25.
//

import XCTest

func makeUITestApplication() -> XCUIApplication {
    let app = XCUIApplication()
    app.launchEnvironment["CLIPPY_UI_TESTING"] = "1"
    return app
}

func makeFullStartupAccessibilityPromptApplication() -> XCUIApplication {
    let app = XCUIApplication()
    app.launchEnvironment["CLIPPY_FORCE_ACCESSIBILITY_ALERT"] = "1"
    app.launchArguments = [
        "-hasLaunchedBefore", "YES",
        "-hideDockIcon", "YES",
        "-hideMenuBarIcon", "NO",
        "-autoUpdateEnabled", "NO",
        "-startAtLogin", "NO"
    ]
    return app
}

func launchFresh(_ app: XCUIApplication) {
    terminateRunningClippyInstances()
    
    if app.state != .notRunning {
        app.terminate()
        XCTAssertTrue(app.wait(for: .notRunning, timeout: 5))
    }
    app.launch()
}

func terminateRunningClippyInstances() {
    let runningApp = XCUIApplication(bundleIdentifier: "com.andrewladd.Lippy")
    if runningApp.state != .notRunning {
        runningApp.terminate()
        XCTAssertTrue(runningApp.wait(for: .notRunning, timeout: 5))
    }
}

final class ClippyUITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        terminateRunningClippyInstances()
    }

    @MainActor
    func testAppLaunchesWithoutAccessibilityPrompt() throws {
        let app = makeUITestApplication()
        launchFresh(app)

        XCTAssertNotEqual(app.state, .notRunning)
        XCTAssertFalse(app.alerts["Accessibility Permissions Required"].waitForExistence(timeout: 1))
    }
    
    @MainActor
    func testFullStartupShowsAccessibilityPromptAndKeepsRunning() throws {
        let app = makeFullStartupAccessibilityPromptApplication()
        launchFresh(app)
        
        let accessibilityAlert = app.dialogs.containing(.staticText, identifier: "Accessibility Permissions Required").firstMatch
        XCTAssertTrue(accessibilityAlert.waitForExistence(timeout: 5))
        XCTAssertNotEqual(app.state, .notRunning)
        
        accessibilityAlert.buttons["Later"].click()
        XCTAssertNotEqual(app.state, .notRunning)
    }

}
