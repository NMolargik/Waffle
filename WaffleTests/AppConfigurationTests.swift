//
//  AppConfigurationTests.swift
//  WaffleTests
//

import Testing
import Foundation
@testable import Waffle

struct AppConfigurationTests {
    @Test func addressBarFillsAvailableSpace() {
        let width = AppConfiguration.addressBarWidth(forWindowWidth: 1000, reservedForControls: 430)
        #expect(width == 570)
    }

    @Test func addressBarNeverShrinksPastMinimum() {
        let width = AppConfiguration.addressBarWidth(forWindowWidth: 400, reservedForControls: 430)
        #expect(width == AppConfiguration.addressBarMinWidth)
    }

    @Test func addressBarIsCappedOnHugeDisplays() {
        let width = AppConfiguration.addressBarWidth(forWindowWidth: 5000, reservedForControls: 430)
        #expect(width == AppConfiguration.addressBarMaxWidth)
    }
}
