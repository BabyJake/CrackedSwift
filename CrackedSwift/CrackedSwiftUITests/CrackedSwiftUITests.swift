//
//  CrackedSwiftUITests.swift
//  CrackedSwiftUITests
//
//  Created by Jacob Taylor on 02/11/2025.
//

import XCTest

final class CrackedSwiftUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testAppLaunches() throws {
        let app = XCUIApplication()
        app.launch()
    }
}
