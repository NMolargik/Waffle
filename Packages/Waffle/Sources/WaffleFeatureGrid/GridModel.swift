//
//  GridModel.swift
//  WaffleFeatureGrid
//
//  Observable state for the waffle grid: cells, selection, pop-out tracking, and
//  debounced snapshot persistence through the `KeyValueStoring` seam. (Successor to the
//  monolith's `WaffleState`.)
//

import Foundation
import os
import WaffleCore

@Observable
@MainActor
public final class GridModel {
    public var waffleRows = [[WaffleCell]]()

    public var selectedCell: WaffleCell? = nil {
        didSet { persistDebounced() }
    }
    public var poppedCell: WaffleCell? = nil

    /// Mirrors the selected cell's address for the toolbar address bar.
    public var addressText: String = ""

    /// Incremented each time the user touches a phone pane (selected or not), so the
    /// hosting window can end address editing like Safari does when you touch the page.
    public private(set) var paneTouchCount = 0

    public func notePaneTouched() { paneTouchCount += 1 }

    public var canPopOut: Bool { selectedCell != nil && poppedCell == nil }

    /// iPhone/Duo pane ratios. Only meaningful on phones; persisted with the snapshot so a
    /// layout survives relaunch and fold transitions exactly as the user left it.
    public var paneRatios = PaneRatios.default {
        didSet { persistDebounced() }
    }

    public var rowCount = 1 {
        didSet { resizeGrid() }
    }

    public var colCount = 1 {
        didSet { resizeGrid() }
    }

    // MARK: - Persistence

    public static let snapshotKey = "lastGridSnapshot"

    private let defaults: any KeyValueStoring
    private var persistenceTask: Task<Void, Never>?

    // MARK: - Auto-refresh

    /// Whether the app scene is active. Cell timers only run (and only reload) while true;
    /// `MainView` drives this from `scenePhase`.
    public private(set) var isAppActive = true

    @ObservationIgnored
    private var refreshTasks: [UUID: Task<Void, Never>] = [:]

    /// When set, decides whether a cell may start auto-refreshing (turning it off is always allowed).
    public var autoRefreshPolicy: (() -> Bool)?
    /// Called instead of applying an interval the policy refused (the session shows the paywall).
    public var onAutoRefreshDenied: (() -> Void)?

    // MARK: - Content blocking

    public let contentBlocking: ContentBlockingController

    public init(defaults: any KeyValueStoring = UserDefaults.standard, blocksContent: Bool = true) {
        self.defaults = defaults
        self.contentBlocking = ContentBlockingController(defaults: defaults, compilesRules: blocksContent)
        contentBlocking.cells = { [weak self] in self?.waffleRows.joined().map { $0 } ?? [] }
    }

    /// Creates a cell wired to the content blocker. All grid cells come through here.
    private func makeCell() -> WaffleCell {
        let cell = WaffleCell()
        cell.blocker = contentBlocking
        return cell
    }

    /// Sets a cell's content-blocking override and applies it right away.
    public func setContentBlockingMode(_ mode: ContentBlockingMode, for cell: WaffleCell) {
        cell.contentBlockingMode = mode
        contentBlocking.refresh(cell)
        persistDebounced()
    }

    /// Adds or removes the cell's current site from the blocking exceptions.
    public func toggleBlockingException(for cell: WaffleCell) {
        if contentBlocking.hasException(for: cell.address) {
            if let host = ContentBlockingPolicy.normalizedHost(from: cell.address) {
                // Remove the exact entry or the parent entry that covers this host.
                for entry in contentBlocking.exceptionHosts where ContentBlockingPolicy.isException(host: host, in: [entry]) {
                    contentBlocking.removeException(host: entry)
                }
            }
        } else {
            contentBlocking.addException(for: cell.address)
        }
    }

    /// Row-major raw modes, for snapshots.
    public func flattenedContentBlockingModes() -> [Int] {
        waffleRows.flatMap { row in row.map(\.contentBlockingMode.rawValue) }
    }

    /// Sets a cell's auto-refresh cadence, restarts its timer and persists the grid.
    public func setRefreshInterval(_ interval: RefreshInterval, for cell: WaffleCell) {
        // iPhone and Duo gate auto-refresh behind Syrup (iPad leaves the policy unset).
        if interval != .off, let policy = autoRefreshPolicy, !policy() {
            onAutoRefreshDenied?()
            return
        }
        cell.refreshInterval = interval
        restartRefreshTimer(for: cell)
        persistDebounced()
    }

    /// Pauses every timer while the app is inactive/backgrounded; resuming restarts the
    /// countdowns from now (no burst of overdue reloads).
    public func setAppActive(_ active: Bool) {
        guard active != isAppActive else { return }
        isAppActive = active
        restartAllRefreshTimers()
    }

    /// Row-major seconds per cell, for snapshots and presets.
    public func flattenedRefreshIntervals() -> [Int] {
        waffleRows.flatMap { row in row.map(\.refreshInterval.rawValue) }
    }

    /// Cells that currently have auto-refresh scheduled (timers alive).
    public var autoRefreshingCellIDs: Set<UUID> { Set(refreshTasks.keys) }

    func restartAllRefreshTimersForPanes() { restartAllRefreshTimers() }

    private func restartAllRefreshTimers() {
        let live = Set(waffleRows.joined().map(\.id))
        for (id, task) in refreshTasks where !live.contains(id) {
            task.cancel()
            refreshTasks[id] = nil
        }
        for cell in waffleRows.joined() {
            restartRefreshTimer(for: cell)
        }
    }

    private func restartRefreshTimer(for cell: WaffleCell) {
        refreshTasks[cell.id]?.cancel()
        refreshTasks[cell.id] = nil

        var scheduler = AutoRefreshScheduler(interval: cell.refreshInterval, isAppActive: isAppActive, now: Date())
        guard scheduler.isEnabled else { return }

        refreshTasks[cell.id] = Task { @MainActor [weak self, weak cell] in
            while !Task.isCancelled {
                guard let next = scheduler.nextFireDate() else { return }
                let delay = max(0, next.timeIntervalSinceNow)
                try? await Task.sleep(for: .seconds(delay))
                guard !Task.isCancelled, let self, let cell else { return }
                guard self.isAppActive else {
                    // Timers are cancelled on deactivation; this is a safety net.
                    scheduler.appDidResignActive()
                    return
                }
                if scheduler.fireIfDue(now: Date()), !cell.address.isEmpty, !cell.isLoading {
                    Log.grid.debug("Auto-refreshing cell \(cell.id.uuidString, privacy: .public)")
                    cell.reloadCell()
                }
            }
        }
    }

    /// Schedules a debounced snapshot write, coalescing rapid mutations.
    public func persistDebounced() {
        persistenceTask?.cancel()
        persistenceTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(AppConfiguration.persistenceDebounceInterval))
            guard !Task.isCancelled else { return }
            self.persistNow()
        }
    }

    /// Writes the snapshot immediately (e.g. when the scene goes to background).
    public func persistNow() {
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
    public func restoreFromSnapshotIfAvailable() -> Bool {
        guard let data = defaults.data(forKey: Self.snapshotKey), !data.isEmpty,
              let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data) else {
            return false
        }
        apply(snapshot: snapshot)
        return true
    }

    // MARK: - Grid Structure

    private func resizeGrid() {
        waffleRows = GridLayout.resized(waffleRows, rows: rowCount, cols: colCount) { makeCell() }
        if let selected = selectedCell, !contains(selected) {
            select(waffleRows.first?.first)
        }
        restartAllRefreshTimers()
        persistDebounced()
    }

    /// Resizes the grid, clamping into the allowed bounds.
    public func setGridSize(rows: Int, cols: Int, maxRows: Int, maxCols: Int) {
        let clamped = GridLayout.clamped(rows: rows, cols: cols, maxRows: maxRows, maxCols: maxCols)
        if rowCount != clamped.rows { rowCount = clamped.rows }
        if colCount != clamped.cols { colCount = clamped.cols }
    }

    public func makeInitialItem() {
        guard waffleRows.isEmpty else { return }
        let firstRow = [makeCell()]
        waffleRows = [firstRow]
        select(firstRow.first)
    }

    private func contains(_ cell: WaffleCell) -> Bool {
        waffleRows.contains { $0.contains(cell) }
    }

    // MARK: - Selection

    public func select(_ cell: WaffleCell?) {
        selectedCell = cell
        addressText = cell?.address ?? ""
    }

    /// Loads a URL string into the selected cell and syncs the address bar.
    public func loadInSelectedCell(_ urlString: String) {
        selectedCell?.loadURL(urlString: urlString)
        addressText = urlString
        persistDebounced()
    }

    /// Normalizes raw address-bar input and loads it into the selected cell.
    ///
    /// - Parameter paneID: the pane whose address was being edited. A submit only ever
    ///   navigates that pane, even if the selection moved since editing began (phones
    ///   select a pane by touching it); the address bar then shows the selected pane again.
    public func submitAddress(using provider: SearchProvider, toPaneID paneID: UUID? = nil) {
        let final = AddressNormalizer.normalize(addressText, using: provider)
        if let paneID, paneID != selectedCell?.id {
            addressText = selectedCell?.address ?? ""
            if let target = panes.first(where: { $0.id == paneID }) {
                target.loadURL(urlString: final)
                persistDebounced()
            }
            return
        }
        loadInSelectedCell(final)
    }

    /// Called when a cell's page navigates, to keep the address bar in sync.
    public func noteAddressChange(for cell: WaffleCell) {
        contentBlocking.refresh(cell)
        if selectedCell == cell {
            addressText = cell.address
        }
        persistDebounced()
    }

    // MARK: - Pop Out / Pop Back

    public func popOut(_ cell: WaffleCell) {
        poppedCell = cell
    }

    public func popBack(poppedCellAddress: String) {
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

    public func isPoppedOut(_ cell: WaffleCell) -> Bool {
        poppedCell == cell
    }

    // MARK: - Snapshots

    public func flattenedAddresses() -> [String] {
        waffleRows.flatMap { row in row.map(\.address) }
    }

    public func makeSnapshot() -> Snapshot {
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
            selectedIndex: selectedIndex,
            refreshIntervals: flattenedRefreshIntervals(),
            contentBlockingModes: flattenedContentBlockingModes(),
            paneRatios: paneRatios.array
        )
    }

    public func apply(snapshot: Snapshot) {
        rebuildGrid(rows: snapshot.rows, cols: snapshot.cols, urls: snapshot.urls, refreshIntervals: snapshot.refreshIntervals, contentBlockingModes: snapshot.contentBlockingModes)
        paneRatios = PaneRatios(array: snapshot.paneRatios)

        if let flat = snapshot.selectedIndex, flat >= 0 {
            let position = GridLayout.position(of: flat, columnCount: colCount)
            if position.row < waffleRows.count, position.column < waffleRows[position.row].count {
                select(waffleRows[position.row][position.column])
                return
            }
        }
        select(waffleRows.first?.first)
    }

    public func apply(preset: Preset, maxRows: Int, maxCols: Int) {
        let clamped = GridLayout.clamped(rows: preset.rows, cols: preset.cols, maxRows: maxRows, maxCols: maxCols)
        // Intervals are row-major against the preset's own column count; re-flow them
        // when clamping changes the shape so each URL keeps its own cadence.
        let intervals = GridLayout.rowMajorURLs(
            preset.refreshIntervals.map(String.init), rows: preset.rows, cols: preset.cols, fill: "0"
        )
        .prefix(clamped.rows).flatMap { $0.prefix(clamped.cols) }.compactMap { Int($0) }
        let urls = GridLayout.rowMajorURLs(preset.urls, rows: preset.rows, cols: preset.cols, fill: AppConfiguration.fallbackURL)
            .prefix(clamped.rows).flatMap { $0.prefix(clamped.cols) }
        rebuildGrid(rows: clamped.rows, cols: clamped.cols, urls: Array(urls), refreshIntervals: intervals)
        select(waffleRows.first?.first)
    }

    /// Replaces every cell using a reordered flat URL list (rearrange sheet). Cadences
    /// follow their URL.
    public func applyReorderedURLs(_ urls: [String]) {
        let byAddress = Dictionary(waffleRows.joined().map { ($0.address, $0.refreshInterval.rawValue) }, uniquingKeysWith: { first, _ in first })
        let intervals = urls.map { byAddress[$0] ?? 0 }
        let modesByAddress = Dictionary(waffleRows.joined().map { ($0.address, $0.contentBlockingMode.rawValue) }, uniquingKeysWith: { first, _ in first })
        let modes = urls.map { modesByAddress[$0] ?? 0 }
        rebuildGrid(rows: rowCount, cols: colCount, urls: urls, refreshIntervals: intervals, contentBlockingModes: modes)
        select(waffleRows.first?.first)
    }

    private func rebuildGrid(rows: Int, cols: Int, urls: [String], refreshIntervals: [Int] = [], contentBlockingModes: [Int] = []) {
        rowCount = max(1, rows)
        colCount = max(1, cols)

        let layout = GridLayout.rowMajorURLs(urls, rows: rowCount, cols: colCount, fill: AppConfiguration.fallbackURL)
        let intervals = RefreshInterval.intervals(from: refreshIntervals, count: rowCount * colCount)
        let modes = ContentBlockingMode.modes(from: contentBlockingModes, count: rowCount * colCount)
        waffleRows = layout.enumerated().map { rowIndex, row in
            row.enumerated().map { columnIndex, urlString in
                let cell = makeCell()
                let flat = GridLayout.index(row: rowIndex, column: columnIndex, columnCount: colCount)
                cell.refreshInterval = intervals[flat]
                cell.contentBlockingMode = modes[flat]
                cell.loadURL(urlString: urlString)
                return cell
            }
        }
        restartAllRefreshTimers()
        persistDebounced()
    }
}

public extension GridModel {
    /// The grid's current slots as lightweight rearrange models (id, url, title).
    func rearrangeCells() -> [RearrangeCell] {
        waffleRows.flatMap { row in
            row.map { RearrangeCell(id: UUID(), url: $0.address, title: $0.page.title) }
        }
    }
}

// MARK: - Panes (iPhone and iPhone Duo)

/// What applying a saved layout to the phone workspace did.
public struct PaneApplyResult: Equatable, Sendable {
    /// Panes now open.
    public let opened: Int
    /// Panes the saved layout held; greater than `opened` when this display or plan can't fit them all.
    public let saved: Int
    public var wasTruncated: Bool { opened < saved }
}

/// Phones keep their panes in the grid's single row (`rowCount == 1`, `colCount == panes`)
/// so snapshots, auto-refresh, content blocking and selection all work unchanged, and
/// cells (and therefore loaded pages) survive every layout change without reloading.
public extension GridModel {
    /// The open panes in order.
    var panes: [WaffleCell] { waffleRows.flatMap { $0 } }

    var paneCount: Int { panes.count }

    var selectedPaneIndex: Int? {
        selectedCell.flatMap { panes.firstIndex(of: $0) }
    }

    /// Appends an empty pane and selects it.
    @discardableResult
    func addPane() -> WaffleCell? {
        guard !waffleRows.isEmpty, paneCount < PaneLimits.maxInnerPanes else { return nil }
        if rowCount != 1 { rowCount = 1 }
        colCount = paneCount + 1
        guard let added = panes.last else { return nil }
        select(added)
        return added
    }

    /// Closes a pane (never the last one), selecting its neighbour.
    func removePane(_ cell: WaffleCell) {
        var list = panes
        guard list.count > 1, let index = list.firstIndex(of: cell) else { return }
        let wasSelected = selectedCell == cell
        list.remove(at: index)
        waffleRows = [list]
        rowCount = 1
        colCount = list.count
        if wasSelected { select(list[min(index, list.count - 1)]) }
        restartAllRefreshTimersForPanes()
        persistDebounced()
    }

    /// Swaps two panes' positions without touching their pages.
    func swapPanes(_ first: Int, _ second: Int) {
        let swapped = GridLayout.swapped(panes, first, second)
        guard swapped != panes else { return }
        waffleRows = [swapped]
        persistDebounced()
    }

    /// Trims a restored grid to what the phone workspace can hold: a single row of at
    /// most `maxPanes` panes. A no-op (no reloads) when it already fits.
    func adaptToPanes(maxPanes: Int) {
        let limit = max(1, maxPanes)
        guard !waffleRows.isEmpty, rowCount > 1 || colCount > limit else { return }
        let snapshot = makeSnapshot()
        let keep = min(limit, snapshot.urls.count)
        let selected = snapshot.selectedIndex.flatMap { $0 < keep ? $0 : nil }
        apply(snapshot: Snapshot(
            rows: 1,
            cols: keep,
            urls: Array(snapshot.urls.prefix(keep)),
            selectedIndex: selected ?? 0,
            refreshIntervals: Array(snapshot.refreshIntervals.prefix(keep)),
            contentBlockingModes: Array(snapshot.contentBlockingModes.prefix(keep)),
            paneRatios: paneRatios.array
        ))
    }

    /// Opens a saved layout in the phone workspace: its first `maxPanes` panes, with its
    /// saved ratios. An iPad grid preset opens its first cells in row-major order.
    @discardableResult
    func apply(preset: Preset, maxPanes: Int, keepsAutoRefresh: Bool) -> PaneApplyResult {
        let saved = PaneLimits.savedSlotCount(paneCount: preset.paneCount, rows: preset.rows, cols: preset.cols)
        let opened = max(1, min(saved, maxPanes))
        let urls = GridLayout.rowMajorURLs(preset.urls, rows: preset.rows, cols: preset.cols, fill: AppConfiguration.fallbackURL)
            .flatMap { $0 }
        let intervals = keepsAutoRefresh ? Array(preset.refreshIntervals.prefix(opened)) : []
        applyPaneLayout(urls: Array(urls.prefix(opened)), refreshIntervals: intervals, ratios: PaneRatios(array: preset.paneRatios))
        return PaneApplyResult(opened: opened, saved: saved)
    }

    /// Replaces every pane with `urls` (one row) and the given ratios.
    func applyPaneLayout(urls: [String], refreshIntervals: [Int] = [], ratios: PaneRatios) {
        let count = max(1, urls.count)
        let snapshot = Snapshot(
            rows: 1,
            cols: count,
            urls: urls.isEmpty ? [AppConfiguration.fallbackURL] : urls,
            selectedIndex: 0,
            refreshIntervals: refreshIntervals,
            paneRatios: ratios.array
        )
        apply(snapshot: snapshot)
    }
}
