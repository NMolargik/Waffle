//
//  WaffleState.swift
//  Waffle
//
//  Created by Nick Molargik on 9/2/25.
//

import Foundation
import os

/// Observable state for the waffle grid: cells, selection, pop-out tracking,
/// and snapshot persistence.
@Observable
@MainActor
final class WaffleState {
    var waffleRows = [[WaffleCell]]()

    var selectedCell: WaffleCell? = nil {
        didSet { persistDebounced() }
    }
    var poppedCell: WaffleCell? = nil

    /// Mirrors the selected cell's address for the toolbar address bar.
    var addressText: String = ""

    var canPopOut: Bool { selectedCell != nil && poppedCell == nil }

    var rowCount = 1 {
        didSet { resizeGrid() }
    }

    var colCount = 1 {
        didSet { resizeGrid() }
    }

    // MARK: - Persistence

    static let snapshotKey = "lastGridSnapshot"

    private let defaults: KeyValueStoring
    private var persistenceTask: Task<Void, Never>?

    init(defaults: KeyValueStoring = UserDefaults.standard) {
        self.defaults = defaults
    }

    /// Schedules a debounced snapshot write, coalescing rapid mutations.
    func persistDebounced() {
        persistenceTask?.cancel()
        persistenceTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(AppConfiguration.persistenceDebounceInterval))
            guard !Task.isCancelled else { return }
            self.persistNow()
        }
    }

    /// Writes the snapshot immediately (e.g. when the scene goes to background).
    func persistNow() {
        persistenceTask?.cancel()
        guard !waffleRows.isEmpty else { return }
        do {
            let data = try JSONEncoder().encode(makeSnapshot())
            defaults.set(data, forKey: Self.snapshotKey)
        } catch {
            Log.grid.error("Failed to encode grid snapshot: \(error.localizedDescription)")
        }
    }

    /// Restores the last persisted grid, if any.
    /// - Returns: true when a snapshot was found and applied.
    @discardableResult
    func restoreFromSnapshotIfAvailable() -> Bool {
        guard let data = defaults.data(forKey: Self.snapshotKey), !data.isEmpty,
              let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data) else {
            return false
        }
        apply(snapshot: snapshot)
        return true
    }

    // MARK: - Grid Structure

    private func resizeGrid() {
        waffleRows = GridLayout.resized(waffleRows, rows: rowCount, cols: colCount) { WaffleCell() }
        if let selected = selectedCell, !contains(selected) {
            select(waffleRows.first?.first)
        }
        persistDebounced()
    }

    /// Resizes the grid, clamping into the allowed bounds.
    func setGridSize(rows: Int, cols: Int, maxRows: Int, maxCols: Int) {
        let clamped = GridLayout.clamped(rows: rows, cols: cols, maxRows: maxRows, maxCols: maxCols)
        if rowCount != clamped.rows { rowCount = clamped.rows }
        if colCount != clamped.cols { colCount = clamped.cols }
    }

    func makeInitialItem() {
        guard waffleRows.isEmpty else { return }
        let firstRow = [WaffleCell()]
        waffleRows = [firstRow]
        select(firstRow.first)
    }

    private func contains(_ cell: WaffleCell) -> Bool {
        waffleRows.contains { $0.contains(cell) }
    }

    // MARK: - Selection

    func select(_ cell: WaffleCell?) {
        selectedCell = cell
        addressText = cell?.address ?? ""
    }

    /// Loads a URL string into the selected cell and syncs the address bar.
    func loadInSelectedCell(_ urlString: String) {
        selectedCell?.loadURL(urlString: urlString)
        addressText = urlString
        persistDebounced()
    }

    /// Normalizes raw address-bar input and loads it into the selected cell.
    func submitAddress(using provider: SearchProvider) {
        let final = AddressNormalizer.normalize(addressText, using: provider)
        loadInSelectedCell(final)
    }

    /// Called when a cell's page navigates, to keep the address bar in sync.
    func noteAddressChange(for cell: WaffleCell) {
        if selectedCell == cell {
            addressText = cell.address
        }
        persistDebounced()
    }

    // MARK: - Pop Out / Pop Back

    func popOut(_ cell: WaffleCell) {
        poppedCell = cell
    }

    func popBack(poppedCellAddress: String) {
        let trimmed = poppedCellAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        if let cell = poppedCell {
            // Only reload when the address actually changed while detached,
            // to avoid a needless reload flash on pop back.
            if !trimmed.isEmpty, trimmed != cell.address {
                cell.loadURL(urlString: trimmed)
            }
            select(cell)
            poppedCell = nil
        } else if !trimmed.isEmpty {
            // No popped cell tracked; fall back to selecting a matching cell.
            if let match = waffleRows.joined().first(where: { $0.address == trimmed }) {
                select(match)
            }
        }
        persistDebounced()
    }

    func isPoppedOut(_ cell: WaffleCell) -> Bool {
        poppedCell == cell
    }

    // MARK: - Snapshots

    func flattenedAddresses() -> [String] {
        waffleRows.flatMap { row in row.map(\.address) }
    }

    func makeSnapshot() -> Snapshot {
        var selectedIndex: Int? = nil
        if let selected = selectedCell {
            for (r, row) in waffleRows.enumerated() {
                if let c = row.firstIndex(of: selected) {
                    selectedIndex = GridLayout.index(row: r, column: c, columnCount: colCount)
                    break
                }
            }
        }
        return Snapshot(
            rows: max(1, rowCount),
            cols: max(1, colCount),
            urls: flattenedAddresses(),
            selectedIndex: selectedIndex
        )
    }

    func apply(snapshot: Snapshot) {
        rebuildGrid(rows: snapshot.rows, cols: snapshot.cols, urls: snapshot.urls)

        if let flat = snapshot.selectedIndex, flat >= 0 {
            let position = GridLayout.position(of: flat, columnCount: colCount)
            if position.row < waffleRows.count, position.column < waffleRows[position.row].count {
                select(waffleRows[position.row][position.column])
                return
            }
        }
        select(waffleRows.first?.first)
    }

    func apply(preset: Preset, maxRows: Int, maxCols: Int) {
        let clamped = GridLayout.clamped(rows: preset.rows, cols: preset.cols, maxRows: maxRows, maxCols: maxCols)
        rebuildGrid(rows: clamped.rows, cols: clamped.cols, urls: preset.urls)
        select(waffleRows.first?.first)
    }

    /// Replaces every cell using a reordered flat URL list (rearrange sheet).
    func applyReorderedURLs(_ urls: [String]) {
        rebuildGrid(rows: rowCount, cols: colCount, urls: urls)
        select(waffleRows.first?.first)
    }

    private func rebuildGrid(rows: Int, cols: Int, urls: [String]) {
        rowCount = max(1, rows)
        colCount = max(1, cols)

        let layout = GridLayout.rowMajorURLs(urls, rows: rowCount, cols: colCount, fill: AppConfiguration.fallbackURL)
        waffleRows = layout.map { row in
            row.map { urlString in
                let cell = WaffleCell()
                cell.loadURL(urlString: urlString)
                return cell
            }
        }
        persistDebounced()
    }
}
