//
//  AppConfigurationTests.swift
//  WaffleCoreTests
//

import Testing
import Foundation
import WaffleCore

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

    @Test func editingAddressBarFillsTheWindowUncapped() {
        let width = AppConfiguration.editingAddressBarWidth(forWindowWidth: 1000)
        #expect(width == 1000 - AppConfiguration.addressBarEditingReservedWidth)
        #expect(AppConfiguration.editingAddressBarWidth(forWindowWidth: 5000) > AppConfiguration.addressBarMaxWidth)
    }

    @Test func editingAddressBarKeepsTheMinimumBeforeMeasurement() {
        // Width is 0 until the window is measured; the bar must not collapse.
        #expect(AppConfiguration.editingAddressBarWidth(forWindowWidth: 0) == AppConfiguration.addressBarMinWidth)
    }
}
