//
//  PhoneInteractionTests.swift
//  WaffleFeatureGridTests
//
//  Address editing and auto-refresh behaviour specific to the phone pane workspace.
//

import Foundation
import Testing
import WaffleCore
@testable import WaffleFeatureGrid

@Suite("Phone panes: address and timers")
@MainActor
struct PhoneInteractionTests {
    private func makeModel(panes: Int) -> GridModel {
        let model = GridModel(defaults: FakeKeyValueStore(), blocksContent: false)
        model.applyPaneLayout(urls: (0..<panes).map { "https://example.com/\($0)" }, ratios: .default)
        return model
    }

    // MARK: A5: hidden panes do not auto-refresh

    @Test func hiddenPanesPauseTheirTimersAndResumeWhenShown() {
        let model = makeModel(panes: 3)
        let panes = model.panes
        for pane in panes { model.setRefreshInterval(.thirtySeconds, for: pane) }
        #expect(model.autoRefreshingCellIDs == Set(panes.map(\.id)))

        // Pane 2 is focused alone (outer display / maximized): the other two are hidden.
        model.setHiddenCells([panes[0].id, panes[2].id])
        #expect(model.autoRefreshingCellIDs == [panes[1].id])

        model.setHiddenCells([])
        #expect(model.autoRefreshingCellIDs == Set(panes.map(\.id)))
    }

    @Test func hiddenStateSurvivesBackgroundingAndNeverResurrectsTimers() {
        let model = makeModel(panes: 2)
        let panes = model.panes
        model.setRefreshInterval(.oneMinute, for: panes[0])
        model.setHiddenCells([panes[0].id])
        model.setAppActive(false)
        model.setAppActive(true)
        #expect(model.autoRefreshingCellIDs.isEmpty, "a hidden pane stays paused after the app returns to the foreground")
    }

    @Test func aTimerSetOnAHiddenPaneWaitsUntilItIsShown() {
        let model = makeModel(panes: 2)
        let panes = model.panes
        model.setHiddenCells([panes[1].id])
        model.setRefreshInterval(.thirtySeconds, for: panes[1])
        #expect(model.autoRefreshingCellIDs.isEmpty)
        model.setHiddenCells([])
        #expect(model.autoRefreshingCellIDs == [panes[1].id])
    }

    // MARK: A1: a submit only navigates the pane being edited

    @Test func submitNavigatesTheEditedPaneEvenAfterTheSelectionMoved() {
        let model = makeModel(panes: 2)
        let first = model.panes[0], second = model.panes[1]
        model.select(first)
        let editingID = first.id
        // The user types, then touches pane 2 (which selects it and rewrites the address text).
        model.addressText = "https://typed.example"
        model.select(second)
        model.addressText = "https://typed.example"   // what the field writes back on Return
        model.submitAddress(using: .google, toPaneID: editingID)
        #expect(first.address == "https://typed.example")
        #expect(second.address == "https://example.com/1")
        // The bar goes back to showing the selected pane.
        #expect(model.addressText == "https://example.com/1")
    }

    @Test func submitWithoutATargetNavigatesTheSelectedPane() {
        let model = makeModel(panes: 2)
        model.select(model.panes[1])
        model.addressText = "https://typed.example"
        model.submitAddress(using: .google)
        #expect(model.panes[1].address == "https://typed.example")
        #expect(model.panes[0].address == "https://example.com/0")
    }

    @Test func submitToAClosedPaneNavigatesNothing() {
        let model = makeModel(panes: 2)
        let doomed = model.panes[0]
        model.select(doomed)
        model.removePane(doomed)
        model.addressText = "https://typed.example"
        model.submitAddress(using: .google, toPaneID: doomed.id)
        #expect(model.panes.map(\.address) == ["https://example.com/1"])
    }
}
