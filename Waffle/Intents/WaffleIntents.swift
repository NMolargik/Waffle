//
//  WaffleIntents.swift
//  Waffle
//
//  App Intents for Siri, Shortcuts, and Spotlight actions.
//

import AppIntents
import Foundation
import WebKit

// MARK: - Open Preset

struct OpenPresetIntent: AppIntent {
    static let title: LocalizedStringResource = "Open Grid Preset"
    static let description = IntentDescription(
        "Opens Waffle and applies one of your saved grid presets.",
        categoryName: "Grid"
    )
    static let openAppWhenRun = true
    static var parameterSummary: some ParameterSummary {
        Summary("Open the \(\.$preset) preset")
    }

    @Parameter(title: "Preset")
    var preset: PresetEntity

    @Dependency private var coordinator: WaffleCoordinator

    @MainActor
    func perform() async throws -> some IntentResult {
        coordinator.handle(.openPreset(preset.id))
        return .result()
    }
}

// MARK: - Open Bookmark

struct OpenBookmarkIntent: AppIntent {
    static let title: LocalizedStringResource = "Open Bookmark"
    static let description = IntentDescription(
        "Opens Waffle and loads a bookmark into the selected cell.",
        categoryName: "Browsing"
    )
    static let openAppWhenRun = true
    static var parameterSummary: some ParameterSummary {
        Summary("Open \(\.$bookmark) in the selected cell")
    }

    @Parameter(title: "Bookmark")
    var bookmark: BookmarkEntity

    @Dependency private var coordinator: WaffleCoordinator

    @MainActor
    func perform() async throws -> some IntentResult {
        coordinator.handle(.openBookmark(bookmark.id))
        return .result()
    }
}

// MARK: - Set Grid Size

struct SetGridSizeIntent: AppIntent {
    static let title: LocalizedStringResource = "Set Grid Size"
    static let description = IntentDescription(
        "Resizes the Waffle browsing grid.",
        categoryName: "Grid"
    )
    static let openAppWhenRun = true
    static var parameterSummary: some ParameterSummary {
        Summary("Resize the grid to \(\.$rows) by \(\.$columns)")
    }

    @Parameter(title: "Rows", default: 2, inclusiveRange: (1, 4))
    var rows: Int

    @Parameter(title: "Columns", default: 2, inclusiveRange: (1, 4))
    var columns: Int

    @Dependency private var coordinator: WaffleCoordinator

    @MainActor
    func perform() async throws -> some IntentResult {
        coordinator.handle(.setGrid(rows: rows, cols: columns))
        return .result()
    }
}

// MARK: - Bookmark Current Page

struct BookmarkCurrentPageIntent: AppIntent {
    static let title: LocalizedStringResource = "Bookmark Current Page"
    static let description = IntentDescription(
        "Saves the selected cell's page as a bookmark.",
        categoryName: "Browsing"
    )
    static let openAppWhenRun = true

    @Dependency private var coordinator: WaffleCoordinator

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let cell = coordinator.waffleState.selectedCell, !cell.address.isEmpty else {
            return .result(dialog: IntentDialog("There's no page loaded in the selected cell yet."))
        }
        let bookmark = coordinator.library.addBookmark(urlString: cell.address, title: cell.page.title)
        if let bookmark {
            return .result(dialog: IntentDialog("Bookmarked \(bookmark.title)."))
        }
        return .result(dialog: IntentDialog("That page couldn't be bookmarked."))
    }
}
