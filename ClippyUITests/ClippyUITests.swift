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

final class ClippyUITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    @MainActor
    func testAppLaunchesWithoutAccessibilityPrompt() throws {
        let app = makeUITestApplication()
        app.launch()

        XCTAssertNotEqual(app.state, .notRunning)
        XCTAssertFalse(app.alerts["Accessibility Permissions Required"].waitForExistence(timeout: 1))
    }

}
