//
//  GridModelTests.swift
//  WaffleFeatureGridTests
//

import Foundation
import Testing
import WaffleCore
@testable import WaffleFeatureGrid

@Suite("GridModel")
@MainActor
struct GridModelTests {
    private func makeState() -> (GridModel, FakeKeyValueStore) {
        let store = FakeKeyValueStore()
        return (GridModel(defaults: store, blocksContent: false), store)
    }

    // MARK: - Grid sizing

    @Test func rowCountGrowsGrid() {
        let (state, _) = makeState()
        state.makeInitialItem()
        state.rowCount = 3
        #expect(state.waffleRows.count == 3)
        #expect(state.waffleRows.allSatisfy { $0.count == 1 })
    }

    @Test func colCountGrowsEveryRow() {
        let (state, _) = makeState()
        state.makeInitialItem()
        state.rowCount = 2
        state.colCount = 3
        #expect(state.waffleRows.allSatisfy { $0.count == 3 })
    }

    @Test func shrinkingKeepsExistingCells() {
        let (state, _) = makeState()
        state.makeInitialItem()
        state.rowCount = 2
        state.colCount = 2
        let topLeft = state.waffleRows[0][0]
        state.rowCount = 1
        state.colCount = 1
        #expect(state.waffleRows == [[topLeft]])
    }

    @Test func shrinkingReselectsWhenSelectionRemoved() {
        let (state, _) = makeState()
        state.makeInitialItem()
        state.rowCount = 2
        state.select(state.waffleRows[1][0])
        state.rowCount = 1
        #expect(state.selectedCell == state.waffleRows[0][0])
    }

    @Test func setGridSizeClampsToLimits() {
        let (state, _) = makeState()
        state.makeInitialItem()
        state.setGridSize(rows: 10, cols: 10, maxRows: 4, maxCols: 4)
        #expect(state.rowCount == 4)
        #expect(state.colCount == 4)
    }

    // MARK: - Selection / address bar

    @Test func selectingCellSyncsAddressText() {
        let (state, _) = makeState()
        state.makeInitialItem()
        state.selectedCell?.address = "https://apple.com"
        state.select(state.selectedCell)
        #expect(state.addressText == "https://apple.com")
    }

    @Test func noteAddressChangeOnlyUpdatesForSelectedCell() {
        let (state, _) = makeState()
        state.makeInitialItem()
        state.colCount = 2
        let other = state.waffleRows[0][1]
        other.address = "https://example.org"
        state.noteAddressChange(for: other)
        #expect(state.addressText != "https://example.org")
    }

    // MARK: - Pop out / pop back

    @Test func popOutAndBackRestoresSelection() {
        let (state, _) = makeState()
        state.makeInitialItem()
        let cell = state.waffleRows[0][0]
        cell.address = "https://apple.com"
        state.popOut(cell)
        #expect(state.isPoppedOut(cell))
        #expect(!state.canPopOut)

        state.popBack(poppedCellAddress: "https://apple.com")
        #expect(state.poppedCell == nil)
        #expect(state.selectedCell == cell)
    }

    // MARK: - Snapshots

    @Test func snapshotRoundTripPreservesLayoutAndSelection() {
        let (state, _) = makeState()
        state.makeInitialItem()
        state.rowCount = 2
        state.colCount = 2
        for (i, cell) in state.waffleRows.joined().enumerated() {
            cell.address = "https://site\(i).example"
        }
        state.select(state.waffleRows[1][1])

        let snapshot = state.makeSnapshot()
        #expect(snapshot.rows == 2)
        #expect(snapshot.cols == 2)
        #expect(snapshot.selectedIndex == 3)

        let (restored, _) = makeState()
        restored.apply(snapshot: snapshot)
        #expect(restored.flattenedAddresses() == snapshot.urls)
        #expect(restored.selectedCell == restored.waffleRows[1][1])
    }

    @Test func persistAndRestoreThroughKeyValueStore() {
        let store = FakeKeyValueStore()
        let state = GridModel(defaults: store, blocksContent: false)
        state.makeInitialItem()
        state.colCount = 2
        state.waffleRows[0][0].address = "https://apple.com"
        state.persistNow()

        #expect(store.data(forKey: GridModel.snapshotKey) != nil)

        let restored = GridModel(defaults: store, blocksContent: false)
        #expect(restored.restoreFromSnapshotIfAvailable())
        #expect(restored.colCount == 2)
        #expect(restored.flattenedAddresses().first == "https://apple.com")
    }

    @Test func restoreReturnsFalseWhenNothingPersisted() {
        let (state, _) = makeState()
        #expect(!state.restoreFromSnapshotIfAvailable())
    }

    // MARK: - Preset / reorder application

    @Test func applyPresetClampsToFreeLimits() {
        let (state, _) = makeState()
        let preset = Preset(name: "Big", rows: 4, cols: 4, urls: Array(repeating: "https://apple.com", count: 16))
        state.apply(preset: preset, maxRows: 2, maxCols: 2)
        #expect(state.rowCount == 2)
        #expect(state.colCount == 2)
        #expect(state.flattenedAddresses().count == 4)
    }

    @Test func applyPresetPadsMissingURLsWithFallback() {
        let (state, _) = makeState()
        let preset = Preset(name: "Sparse", rows: 2, cols: 2, urls: ["https://apple.com"])
        state.apply(preset: preset, maxRows: 4, maxCols: 4)
        let addresses = state.flattenedAddresses()
        #expect(addresses[0] == "https://apple.com")
        #expect(addresses.dropFirst().allSatisfy { $0 == AppConfiguration.fallbackURL })
    }

    @Test func applyReorderedURLsKeepsGridShape() {
        let (state, _) = makeState()
        state.makeInitialItem()
        state.colCount = 2
        state.applyReorderedURLs(["https://b.example", "https://a.example"])
        #expect(state.rowCount == 1)
        #expect(state.colCount == 2)
        #expect(state.flattenedAddresses() == ["https://b.example", "https://a.example"])
    }
}

// MARK: - Auto-refresh

@Suite("GridModel auto-refresh")
@MainActor
struct GridModelAutoRefreshTests {
    @Test func intervalsPersistInSnapshot() {
        let store = FakeKeyValueStore()
        let state = GridModel(defaults: store, blocksContent: false)
        state.makeInitialItem()
        state.colCount = 2
        state.waffleRows[0][0].address = "https://a.example"
        state.waffleRows[0][1].address = "https://b.example"
        state.setRefreshInterval(.fiveMinutes, for: state.waffleRows[0][1])
        state.persistNow()

        let restored = GridModel(defaults: store, blocksContent: false)
        #expect(restored.restoreFromSnapshotIfAvailable())
        #expect(restored.flattenedRefreshIntervals() == [0, 300])
        #expect(restored.waffleRows[0][1].refreshInterval == .fiveMinutes)
    }

    @Test func presetIntervalsFollowTheirURLs() {
        let state = GridModel(defaults: FakeKeyValueStore(), blocksContent: false)
        let preset = Preset(
            name: "Dash", rows: 1, cols: 3,
            urls: ["https://a.example", "https://b.example", "https://c.example"],
            refreshIntervals: [30, 0, 900]
        )
        state.apply(preset: preset, maxRows: 4, maxCols: 4)
        #expect(state.flattenedRefreshIntervals() == [30, 0, 900])

        // Clamping to 1x2 keeps each URL's own cadence.
        let clamped = GridModel(defaults: FakeKeyValueStore(), blocksContent: false)
        clamped.apply(preset: preset, maxRows: 1, maxCols: 2)
        #expect(clamped.flattenedAddresses() == ["https://a.example", "https://b.example"])
        #expect(clamped.flattenedRefreshIntervals() == [30, 0])
    }

    @Test func timersOnlyRunWhileActive() {
        let state = GridModel(defaults: FakeKeyValueStore(), blocksContent: false)
        state.makeInitialItem()
        let cell = state.waffleRows[0][0]
        cell.address = "https://a.example"
        #expect(state.autoRefreshingCellIDs.isEmpty)

        state.setRefreshInterval(.thirtySeconds, for: cell)
        #expect(state.autoRefreshingCellIDs == [cell.id])

        state.setAppActive(false)
        #expect(state.autoRefreshingCellIDs.isEmpty)

        state.setAppActive(true)
        #expect(state.autoRefreshingCellIDs == [cell.id])

        state.setRefreshInterval(.off, for: cell)
        #expect(state.autoRefreshingCellIDs.isEmpty)
    }

    @Test func reorderKeepsCadenceWithURL() {
        let state = GridModel(defaults: FakeKeyValueStore(), blocksContent: false)
        state.makeInitialItem()
        state.colCount = 2
        state.waffleRows[0][0].address = "https://a.example"
        state.waffleRows[0][1].address = "https://b.example"
        state.setRefreshInterval(.oneMinute, for: state.waffleRows[0][0])
        state.applyReorderedURLs(["https://b.example", "https://a.example"])
        #expect(state.flattenedRefreshIntervals() == [0, 60])
    }
}

// MARK: - Phone panes

@Suite("GridModel panes")
@MainActor
struct GridModelPaneTests {
    private func makeModel(panes: Int) -> GridModel {
        let model = GridModel(defaults: FakeKeyValueStore(), blocksContent: false)
        model.applyPaneLayout(urls: (0..<panes).map { "https://example.com/\($0)" }, ratios: .default)
        return model
    }

    @Test func panesLiveInOneRow() {
        let model = makeModel(panes: 3)
        #expect(model.rowCount == 1 && model.colCount == 3)
        #expect(model.paneCount == 3)
        #expect(model.panes.map(\.address) == ["https://example.com/0", "https://example.com/1", "https://example.com/2"])
    }

    @Test func addingAPaneSelectsItAndKeepsTheOthers() {
        let model = makeModel(panes: 2)
        let before = model.panes.map(\.id)
        let added = model.addPane()
        #expect(model.paneCount == 3)
        #expect(model.selectedCell == added)
        #expect(Array(model.panes.map(\.id).prefix(2)) == before)
    }

    @Test func neverMoreThanFourPanes() {
        let model = makeModel(panes: 4)
        #expect(model.addPane() == nil)
        #expect(model.paneCount == 4)
    }

    @Test func removingAPaneKeepsTheSurvivorsPages() {
        let model = makeModel(panes: 3)
        let ids = model.panes.map(\.id)
        model.removePane(model.panes[1])
        #expect(model.panes.map(\.id) == [ids[0], ids[2]])
        #expect(model.colCount == 2)
    }

    @Test func lastPaneCannotBeClosed() {
        let model = makeModel(panes: 1)
        model.removePane(model.panes[0])
        #expect(model.paneCount == 1)
    }

    @Test func closingTheSelectedPaneSelectsANeighbour() {
        let model = makeModel(panes: 3)
        model.select(model.panes[2])
        model.removePane(model.panes[2])
        #expect(model.selectedCell == model.panes[1])
    }

    @Test func swapKeepsCellIdentity() {
        let model = makeModel(panes: 2)
        let ids = model.panes.map(\.id)
        model.swapPanes(0, 1)
        #expect(model.panes.map(\.id) == ids.reversed())
    }

    @Test func ratiosSurviveASnapshotRoundTrip() {
        let store = FakeKeyValueStore()
        let model = GridModel(defaults: store, blocksContent: false)
        model.applyPaneLayout(urls: ["https://a.example", "https://b.example"], ratios: PaneRatios(primary: 0.3, stackA: 0.5, stackB: 0.6))
        model.persistNow()

        let restored = GridModel(defaults: store, blocksContent: false)
        #expect(restored.restoreFromSnapshotIfAvailable())
        #expect(restored.paneRatios == PaneRatios(primary: 0.3, stackA: 0.5, stackB: 0.6))
        #expect(restored.paneCount == 2)
    }

    @Test func adaptingToAPaneLimitKeepsTheFirstPanes() {
        let model = makeModel(panes: 4)
        model.select(model.panes[3])
        model.adaptToPanes(maxPanes: 2)
        #expect(model.paneCount == 2)
        #expect(model.panes.map(\.address) == ["https://example.com/0", "https://example.com/1"])
        #expect(model.selectedCell == model.panes[0])
    }

    @Test func adaptingIsANoOpWhenItAlreadyFits() {
        let model = makeModel(panes: 2)
        let ids = model.panes.map(\.id)
        model.adaptToPanes(maxPanes: 4)
        #expect(model.panes.map(\.id) == ids)
    }

    @Test func ipadGridAdaptsToOneRowOfFirstCells() {
        let model = GridModel(defaults: FakeKeyValueStore(), blocksContent: false)
        model.apply(snapshot: Snapshot(rows: 3, cols: 3, urls: (0..<9).map { "https://example.com/\($0)" }, selectedIndex: 0))
        model.adaptToPanes(maxPanes: 2)
        #expect(model.rowCount == 1 && model.colCount == 2)
        #expect(model.panes.map(\.address) == ["https://example.com/0", "https://example.com/1"])
    }

    @Test func presetFromAnIPadOpensItsFirstPanes() {
        let model = makeModel(panes: 1)
        let preset = Preset(name: "Big", rows: 3, cols: 3, urls: (0..<9).map { "https://big.example/\($0)" })
        let result = model.apply(preset: preset, maxPanes: 2)
        #expect(result == PaneApplyResult(opened: 2, saved: 9))
        #expect(result.wasTruncated)
        #expect(model.panes.map(\.address) == ["https://big.example/0", "https://big.example/1"])
    }

    @Test func paneLayoutRestoresRatiosAndURLs() {
        let model = makeModel(panes: 1)
        let preset = Preset(name: "Three", rows: 2, cols: 2, urls: ["https://a.example", "https://b.example", "https://c.example"], paneCount: 3, paneRatios: [0.4, 0.5, 0.65])
        let result = model.apply(preset: preset, maxPanes: 4)
        #expect(!result.wasTruncated)
        #expect(model.paneCount == 3)
        #expect(model.paneRatios == PaneRatios(primary: 0.4, stackA: 0.5, stackB: 0.65))
        #expect(model.panes.map(\.address) == ["https://a.example", "https://b.example", "https://c.example"])
    }

    @Test func savedRefreshTimersComeBackWithTheLayout() {
        let model = makeModel(panes: 1)
        let preset = Preset(name: "Timed", rows: 1, cols: 2, urls: ["https://a.example", "https://b.example"], refreshIntervals: [30, 60], paneCount: 2)
        model.apply(preset: preset, maxPanes: 2)
        #expect(model.flattenedRefreshIntervals() == [30, 60])
    }

    @Test func olderSnapshotsDecodeWithEvenRatios() throws {
        let json = #"{"rows":1,"cols":2,"urls":["a","b"],"selectedIndex":0}"#
        let snapshot = try JSONDecoder().decode(Snapshot.self, from: Data(json.utf8))
        #expect(PaneRatios(array: snapshot.paneRatios) == .default)
    }
}
