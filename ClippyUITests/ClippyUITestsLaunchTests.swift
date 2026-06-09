//
//  ClippyUITestsLaunchTests.swift
//  ClippyUITests
//
//  Created by Jnani Smart on 22/03/25.
//

import XCTest

final class ClippyUITestsLaunchTests: XCTestCase {

    override class var runsForEachTargetApplicationUIConfiguration: Bool {
        false
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }
    
    override func tearDownWithError() throws {
        terminateRunningClippyInstances()
    }

    @MainActor
    func testLaunch() throws {
        let app = makeUITestApplication()
        launchFresh(app)
        XCTAssertFalse(app.alerts["Accessibility Permissions Required"].waitForExistence(timeout: 1))

        // Insert steps here to perform after app launch but before taking a screenshot,
        // such as logging into a test account or navigating somewhere in the app

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Launch Screen"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
