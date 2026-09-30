//
//  SettingsModel.swift
//  WaffleFeatureSettings
//
//  Drives the settings sheet's data actions: delete-all flows and the DEBUG example-data
//  seeding, all through use-cases with failures surfaced via the ErrorHandler.
//

import Foundation
import Observation
import WaffleCore
import WaffleDesignSystem

@MainActor
@Observable
public final class SettingsModel {

    private let deleteAllBookmarksUseCase: any DeleteAllBookmarks
    private let deleteAllPresetsUseCase: any DeleteAllPresets
    private let addBookmarkUseCase: any AddBookmark
    private let savePresetUseCase: any SavePreset
    private let errorHandler: ErrorHandler

    public init(
        deleteAllBookmarks: any DeleteAllBookmarks,
        deleteAllPresets: any DeleteAllPresets,
        addBookmark: any AddBookmark,
        savePreset: any SavePreset,
        errorHandler: ErrorHandler
    ) {
        self.deleteAllBookmarksUseCase = deleteAllBookmarks
        self.deleteAllPresetsUseCase = deleteAllPresets
        self.addBookmarkUseCase = addBookmark
        self.savePresetUseCase = savePreset
        self.errorHandler = errorHandler
    }

    public func deleteAllBookmarks() {
        do {
            try deleteAllBookmarksUseCase()
        } catch {
            errorHandler.showPersistenceError(error)
        }
    }

    public func deleteAllPresets() {
        do {
            try deleteAllPresetsUseCase()
        } catch {
            errorHandler.showPersistenceError(error)
        }
    }

    #if DEBUG
    /// Seeds a recognizable set of bookmarks and presets for demos/screenshots.
    public func addExampleData() {
        let exampleBookmarks: [(url: String, title: String)] = [
            ("https://www.apple.com", "Apple"),
            ("https://www.google.com", "Google"),
            ("https://www.github.com", "GitHub"),
            ("https://www.wikipedia.org", "Wikipedia"),
            ("https://www.youtube.com", "YouTube"),
            ("https://news.ycombinator.com", "Hacker News"),
        ]
        let examplePresets: [(name: String, rows: Int, cols: Int, urls: [String])] = [
            ("Dev", 4, 4, [
                "https://github.com", "https://stackoverflow.com",
                "https://developer.apple.com", "https://docs.swift.org",
                "https://www.hackingwithswift.com", "https://swiftui.directory",
                "https://www.swift.org/blog", "https://forums.swift.org",
                "https://nshipster.com", "https://www.objc.io",
                "https://www.raywenderlich.com", "https://www.swiftbysundell.com",
                "https://developer.apple.com/documentation/swiftui",
                "https://developer.apple.com/design/human-interface-guidelines",
                "https://testflight.apple.com", "https://appstoreconnect.apple.com",
            ]),
            ("News", 1, 4, [
                "https://www.reuters.com", "https://www.bbc.com/news",
                "https://www.npr.org", "https://apnews.com",
            ]),
            ("Study", 2, 2, [
                "https://www.wikipedia.org", "https://www.khanacademy.org",
                "https://www.wolframalpha.com", "https://scholar.google.com",
            ]),
            ("Space", 2, 3, [
                "https://www.nasa.gov", "https://www.spacex.com",
                "https://www.space.com", "https://www.esa.int",
                "https://hubblesite.org", "https://www.planetary.org",
            ]),
            ("Stocks", 2, 2, [
                "https://www.cnbc.com/markets",
                "https://finance.yahoo.com/chart/AAPL",
                "https://finance.yahoo.com/chart/GOOGL",
                "https://finance.yahoo.com/chart/MSFT",
            ]),
        ]

        do {
            for entry in exampleBookmarks {
                try addBookmarkUseCase(urlString: entry.url, title: entry.title)
            }
            for preset in examplePresets {
                try savePresetUseCase(named: preset.name, rows: preset.rows, cols: preset.cols, urls: preset.urls)
            }
            errorHandler.showToast(String(localized: "Added example data"))
        } catch {
            errorHandler.showPersistenceError(error)
        }
    }
    #endif
}
