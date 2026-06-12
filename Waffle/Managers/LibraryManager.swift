//
//  LibraryManager.swift
//  Waffle
//
//  Owns all Bookmark and Preset persistence so views never write to the
//  model context directly, and CloudKit-backed save failures surface to the user.
//

import Foundation
import SwiftData
import os

/// Central manager for the user's bookmark and preset library.
///
/// Retains the ModelContainer (a bare ModelContext does not keep its container
/// alive) and funnels every save through one error-surfacing path.
@MainActor
@Observable
final class LibraryManager {
    private let container: ModelContainer
    private let errorHandler: ErrorHandler

    /// Invoked after any successful library mutation (used for Spotlight reindexing).
    var libraryDidChange: (() -> Void)?

    private var context: ModelContext { container.mainContext }

    init(container: ModelContainer, errorHandler: ErrorHandler) {
        self.container = container
        self.errorHandler = errorHandler
    }

    // MARK: - Bookmarks

    func bookmarks() -> [Bookmark] {
        let descriptor = FetchDescriptor<Bookmark>(sortBy: [
            SortDescriptor(\.sortIndex, order: .forward),
            SortDescriptor(\.createdAt, order: .reverse)
        ])
        return (try? context.fetch(descriptor)) ?? []
    }

    func bookmark(id: UUID) -> Bookmark? {
        var descriptor = FetchDescriptor<Bookmark>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    @discardableResult
    func addBookmark(urlString: String, title: String?) -> Bookmark? {
        let trimmedURL = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedURL.isEmpty, let url = URL(string: trimmedURL) else {
            errorHandler.showToast(String(localized: "Nothing to bookmark yet"))
            return nil
        }

        let trimmedTitle = title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let bookmark = Bookmark(url: url, title: trimmedTitle.isEmpty ? trimmedURL : trimmedTitle)
        bookmark.sortIndex = (bookmarks().map(\.sortIndex).max() ?? -1) + 1
        context.insert(bookmark)
        save(operation: "add bookmark")
        return bookmark
    }

    func updateBookmark(_ bookmark: Bookmark, title: String, urlString: String) {
        bookmark.title = title
        bookmark.urlString = urlString
        save(operation: "update bookmark")
    }

    func deleteBookmark(_ bookmark: Bookmark) {
        context.delete(bookmark)
        normalizeBookmarkSortIndexes()
        save(operation: "delete bookmark")
    }

    func moveBookmarks(_ ordered: [Bookmark], from source: IndexSet, to destination: Int) {
        let reordered = GridLayout.moved(ordered, fromOffsets: source, toOffset: destination)
        for (index, bookmark) in reordered.enumerated() where bookmark.sortIndex != index {
            bookmark.sortIndex = index
        }
        save(operation: "reorder bookmarks")
    }

    /// Repairs legacy data where every bookmark shares sortIndex 0.
    func normalizeBookmarkSortIndexes() {
        var changed = false
        for (index, bookmark) in bookmarks().enumerated() where bookmark.sortIndex != index {
            bookmark.sortIndex = index
            changed = true
        }
        if changed {
            save(operation: "normalize bookmark order")
        }
    }

    func deleteAllBookmarks() {
        do {
            let all = try context.fetch(FetchDescriptor<Bookmark>())
            all.forEach { context.delete($0) }
            try context.save()
            libraryDidChange?()
            errorHandler.showToast(String(localized: "All bookmarks deleted"))
        } catch {
            errorHandler.showDataError(String(localized: "Failed to delete bookmarks: \(error.localizedDescription)"))
        }
    }

    // MARK: - Presets

    func presets() -> [Preset] {
        let descriptor = FetchDescriptor<Preset>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        return (try? context.fetch(descriptor)) ?? []
    }

    func preset(id: UUID) -> Preset? {
        var descriptor = FetchDescriptor<Preset>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    @discardableResult
    func savePreset(named providedName: String?, rows: Int, cols: Int, urls: [String], now: Date = .now) -> Preset {
        let name: String = {
            if let providedName, !providedName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return providedName
            }
            return String(localized: "Preset \(now.formatted(date: .numeric, time: .shortened))")
        }()
        let preset = Preset(name: name, rows: rows, cols: cols, urls: urls)
        context.insert(preset)
        save(operation: "save preset")
        return preset
    }

    func overwritePreset(_ preset: Preset, rows: Int, cols: Int, urls: [String]) {
        preset.rows = max(1, rows)
        preset.cols = max(1, cols)
        preset.urls = urls
        save(operation: "overwrite preset")
    }

    func renamePreset(_ preset: Preset, to name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        preset.name = trimmed
        save(operation: "rename preset")
    }

    func deletePreset(_ preset: Preset) {
        context.delete(preset)
        save(operation: "delete preset")
    }

    func deleteAllPresets() {
        do {
            let all = try context.fetch(FetchDescriptor<Preset>())
            all.forEach { context.delete($0) }
            try context.save()
            libraryDidChange?()
            errorHandler.showToast(String(localized: "All presets deleted"))
        } catch {
            errorHandler.showDataError(String(localized: "Failed to delete presets: \(error.localizedDescription)"))
        }
    }

    // MARK: - Example Data

    #if DEBUG
    func addExampleData() {
        let exampleBookmarks: [(url: String, title: String)] = [
            ("https://www.apple.com", "Apple"),
            ("https://www.google.com", "Google"),
            ("https://www.github.com", "GitHub"),
            ("https://www.wikipedia.org", "Wikipedia"),
            ("https://www.youtube.com", "YouTube"),
            ("https://news.ycombinator.com", "Hacker News")
        ]
        for (index, entry) in exampleBookmarks.enumerated() {
            if let url = URL(string: entry.url) {
                let bookmark = Bookmark(url: url, title: entry.title)
                bookmark.sortIndex = index
                context.insert(bookmark)
            }
        }

        let examplePresets: [Preset] = [
            Preset(name: "Dev", rows: 4, cols: 4, urls: [
                "https://github.com", "https://stackoverflow.com",
                "https://developer.apple.com", "https://docs.swift.org",
                "https://www.hackingwithswift.com", "https://swiftui.directory",
                "https://www.swift.org/blog", "https://forums.swift.org",
                "https://nshipster.com", "https://www.objc.io",
                "https://www.raywenderlich.com", "https://www.swiftbysundell.com",
                "https://developer.apple.com/documentation/swiftui",
                "https://developer.apple.com/design/human-interface-guidelines",
                "https://testflight.apple.com", "https://appstoreconnect.apple.com"
            ]),
            Preset(name: "News", rows: 1, cols: 4, urls: [
                "https://www.reuters.com", "https://www.bbc.com/news",
                "https://www.npr.org", "https://apnews.com"
            ]),
            Preset(name: "Study", rows: 2, cols: 2, urls: [
                "https://www.wikipedia.org", "https://www.khanacademy.org",
                "https://www.wolframalpha.com", "https://scholar.google.com"
            ]),
            Preset(name: "Space", rows: 2, cols: 3, urls: [
                "https://www.nasa.gov", "https://www.spacex.com",
                "https://www.space.com", "https://www.esa.int",
                "https://hubblesite.org", "https://www.planetary.org"
            ]),
            Preset(name: "Stocks", rows: 2, cols: 2, urls: [
                "https://www.cnbc.com/markets",
                "https://finance.yahoo.com/chart/AAPL",
                "https://finance.yahoo.com/chart/GOOGL",
                "https://finance.yahoo.com/chart/MSFT"
            ])
        ]
        examplePresets.forEach { context.insert($0) }

        save(operation: "add example data")
        errorHandler.showToast(String(localized: "Added example data"))
    }
    #endif

    // MARK: - Saving

    private func save(operation: String) {
        do {
            try context.save()
            libraryDidChange?()
        } catch {
            Log.library.error("Failed to \(operation): \(error.localizedDescription)")
            errorHandler.showDataError(String(localized: "Couldn't save your changes. \(error.localizedDescription)"))
        }
    }
}
