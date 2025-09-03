//
//  MainView-ViewModel.swift
//  Waffle
//
//  Created by Nick Molargik on 9/2/25.
//

import Foundation
import SwiftData

extension MainView {
    @Observable
    class ViewModel {
        // Injected dependencies
        private(set) var coordinator: WaffleCoordinator?

        // UI state
        var addressBarString: String = ""
        var fullScreenCell: WaffleCell? = nil
        var showFullScreenWebView: Bool = false
        var fullscreenTask: Task<Void, Never>? = nil

        // Sheets
        var showSyrupSheet: Bool = false
        var showSettingsSheet: Bool = false
        var showRearrangeSheet: Bool = false

        // Rearrangement
        var pendingReorderedURLs: [String] = []

        func configure(coordinator: WaffleCoordinator) {
            self.coordinator = coordinator
        }

        // MARK: - Address/search

        func normalizedInput(_ input: String, using provider: SearchProvider) -> String {
            let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.isEmpty == false else { return provider.searchURL(for: "") }
            if trimmed.lowercased().hasPrefix("http://") || trimmed.lowercased().hasPrefix("https://") {
                return trimmed
            }
            let hasSpaces = trimmed.contains(where: { $0.isWhitespace })
            let looksLikeDomain = trimmed.contains(".") && !hasSpaces
            let startsWithWWW = trimmed.lowercased().hasPrefix("www.")
            if looksLikeDomain || startsWithWWW {
                return "https://\(trimmed)"
            }
            return provider.searchURL(for: trimmed)
        }

        func submitAddress(using provider: SearchProvider) {
            guard let state = coordinator?.waffleState else { return }
            let final = normalizedInput(addressBarString, using: provider)
            state.selectedCell?.loadURL(urlString: final)
        }

        // MARK: - Toolbar actions

        func goBack() {
            coordinator?.waffleState.selectedCell?.goBack()
        }

        func goForward() {
            coordinator?.waffleState.selectedCell?.goForward()
        }

        func reloadSelected() {
            coordinator?.waffleState.selectedCell?.reloadCell()
        }

        func toggleFullscreen(cell: WaffleCell?) {
            if fullScreenCell == nil {
                fullScreenCell = cell
            } else {
                exitFullscreenSafely()
            }
        }

        @MainActor
        private func exitFullscreenSafely() {
            showFullScreenWebView = false
            fullscreenTask?.cancel()
            fullscreenTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: 50_000_000)
                guard !Task.isCancelled else { return }
                fullScreenCell = nil
            }
        }

        // MARK: - Pop out / Pop back

        func canUsePopout() -> Bool {
            coordinator?.canUsePopout ?? false
        }

        func popOutSelectedCell(openWindow: (WaffleCell) -> Void) {
            guard let state = coordinator?.waffleState else { return }
            guard let cell = state.selectedCell else { return }
            guard !state.isPoppedOut(cell) else { return }
            state.popOut(cell)
            openWindow(cell)
        }

        func initiatePopBack(poppedCellAddress: String, dismissWindow: () -> Void) {
            coordinator?.waffleState.popBack(poppedCellAddress: poppedCellAddress)
            dismissWindow()
        }

        // MARK: - Grid management

        func applyReorderedURLs(_ urls: [String]) {
            guard let state = coordinator?.waffleState else { return }
            let rows = max(1, state.rowCount)
            let cols = max(1, state.colCount)
            state.rowCount = rows
            state.colCount = cols

            state.waffleRows = (0..<rows).map { _ in
                (0..<cols).map { _ in WaffleCell() }
            }
            var idx = 0
            for r in 0..<rows {
                for c in 0..<cols {
                    if idx < urls.count {
                        state.waffleRows[r][c].loadURL(urlString: urls[idx])
                    } else {
                        state.waffleRows[r][c].loadURL(urlString: "https://apple.com")
                    }
                    idx += 1
                }
            }
            state.selectedCell = state.waffleRows.first?.first
        }

        func setRows(_ newValue: Int) {
            guard let coord = coordinator else { return }
            if coord.isSyrupEnabled {
                coord.waffleState.rowCount = min(max(1, newValue), 5)
            } else {
                if newValue > coord.maxFreeRows {
                    coord.requestSyrup()
                    showSyrupSheet = true
                    coord.waffleState.rowCount = coord.maxFreeRows
                } else {
                    coord.waffleState.rowCount = max(1, newValue)
                }
            }
        }

        func setCols(_ newValue: Int) {
            guard let coord = coordinator else { return }
            if coord.isSyrupEnabled {
                coord.waffleState.colCount = min(max(1, newValue), 5)
            } else {
                if newValue > coord.maxFreeCols {
                    coord.requestSyrup()
                    showSyrupSheet = true
                    coord.waffleState.colCount = coord.maxFreeCols
                } else {
                    coord.waffleState.colCount = max(1, newValue)
                }
            }
        }

        // MARK: - Presets / Bookmarks

        func applyPreset(_ preset: Preset) -> Bool {
            guard let coord = coordinator else { return false }
            let overLimit = (!coord.isSyrupEnabled) && (preset.rows > coord.maxFreeRows || preset.cols > coord.maxFreeCols)
            coord.waffleState.apply(
                preset: preset,
                syrupEnabled: coord.isSyrupEnabled,
                maxFreeRows: coord.maxFreeRows,
                maxFreeCols: coord.maxFreeCols
            )
            if overLimit {
                coord.requestSyrup()
                showSyrupSheet = true
            }
            return true
        }

        func saveCurrentGridAsPreset(withName providedName: String?, modelContext: ModelContext) {
            guard let state = coordinator?.waffleState else { return }
            let urls = state.flattenedAddresses()
            let name: String = {
                if let providedName, !providedName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    return providedName
                }
                let formatter = DateFormatter()
                formatter.dateStyle = .short
                formatter.timeStyle = .short
                return "Preset \(formatter.string(from: .now))"
            }()
            let preset = Preset(name: name, rows: state.rowCount, cols: state.colCount, urls: urls)
            modelContext.insert(preset)
            try? modelContext.save()
        }

        func overwritePresetWithCurrentGrid(_ preset: Preset, modelContext: ModelContext) {
            guard let state = coordinator?.waffleState else { return }
            preset.rows = max(1, state.rowCount)
            preset.cols = max(1, state.colCount)
            preset.urls = state.flattenedAddresses()
            try? modelContext.save()
        }

        func applyBookmark(_ bookmark: Bookmark) {
            guard let url = bookmark.url?.absoluteString else { return }
            coordinator?.waffleState.selectedCell?.loadURL(urlString: url)
            addressBarString = url
        }

        func saveCurrentCellAsBookmark(urlString: String, title: String?, modelContext: ModelContext) {
            guard let state = coordinator?.waffleState else { return }
            let effectiveURLString: String = {
                if !urlString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    return urlString
                }
                return state.selectedCell?.address ?? ""
            }()
            guard let url = URL(string: effectiveURLString), !effectiveURLString.isEmpty else { return }

            let effectiveTitle = (title?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false) ? title! : effectiveURLString
            let bookmark = Bookmark(url: url, title: effectiveTitle)
            modelContext.insert(bookmark)
            try? modelContext.save()
        }

        // MARK: - Persistence helpers (produce/consume Data; MainView owns AppStorage)

        func makeGridSnapshotData() -> Data? {
            guard let state = coordinator?.waffleState else { return nil }
            let snapshot = state.makeSnapshot()
            return try? JSONEncoder().encode(snapshot)
        }

        func applyGridSnapshotData(_ data: Data?) -> String {
            guard let state = coordinator?.waffleState else { return "" }
            guard let data, !data.isEmpty else {
                if state.waffleRows.isEmpty {
                    state.makeInitialItem()
                }
                return state.selectedCell?.address ?? ""
            }
            if let snapshot = try? JSONDecoder().decode(WaffleState.Snapshot.self, from: data) {
                state.apply(snapshot: snapshot)
                return state.selectedCell?.address ?? ""
            } else {
                if state.waffleRows.isEmpty {
                    state.makeInitialItem()
                }
                return state.selectedCell?.address ?? ""
            }
        }
    }
}

