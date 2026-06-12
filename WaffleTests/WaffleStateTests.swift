//
//  WaffleStateTests.swift
//  WaffleTests
//

import Foundation
import Testing
@testable import Waffle

@Suite("WaffleState")
@MainActor
struct WaffleStateTests {
    private func makeState() -> (WaffleState, FakeKeyValueStore) {
        let store = FakeKeyValueStore()
        return (WaffleState(defaults: store), store)
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
        let state = WaffleState(defaults: store)
        state.makeInitialItem()
        state.colCount = 2
        state.waffleRows[0][0].address = "https://apple.com"
        state.persistNow()

        #expect(store.data(forKey: WaffleState.snapshotKey) != nil)

        let restored = WaffleState(defaults: store)
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
