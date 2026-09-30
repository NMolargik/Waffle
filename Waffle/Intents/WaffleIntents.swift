//
//  WaffleIntents.swift
//  Waffle
//
//  App Intents for Siri, Shortcuts, and Spotlight actions. Intents route through the
//  session: deep links for navigation, use-cases for writes.
//

import AppIntents
import Foundation
import WaffleComposition
import WaffleCore
import WaffleFeatureGrid
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

    @Dependency private var session: SessionController

    @MainActor
    func perform() async throws -> some IntentResult {
        session.handle(.openPreset(preset.id))
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

    @Dependency private var session: SessionController

    @MainActor
    func perform() async throws -> some IntentResult {
        session.handle(.openBookmark(bookmark.id))
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

    @Dependency private var session: SessionController

    @MainActor
    func perform() async throws -> some IntentResult {
        session.handle(.setGrid(rows: rows, cols: columns))
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

    @Dependency private var session: SessionController

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let cell = session.grid.selectedCell, !cell.address.isEmpty else {
            return .result(dialog: IntentDialog("There's no page loaded in the selected cell yet."))
        }
        let bookmark = try session.addBookmark(urlString: cell.address, title: cell.page.title)
        if let bookmark {
            return .result(dialog: IntentDialog("Bookmarked \(bookmark.title)."))
        }
        return .result(dialog: IntentDialog("That page couldn't be bookmarked."))
    }
}
