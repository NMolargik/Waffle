//
//  SidebarModel.swift
//  WaffleFeatureSidebar
//
//  Drives the sidebar: loads bookmarks/presets through use-cases (no `@Query`), owns the
//  search filter, and routes every mutation through the library use-cases, surfacing
//  failures via the `ErrorHandler` (the old manager toasted from the data layer; now the
//  data layer throws and this model presents).
//

import Foundation
import Observation
import WaffleCore
import WaffleDesignSystem

@MainActor
@Observable
public final class SidebarModel {

    private let loadBookmarksUseCase: any LoadBookmarks
    private let addBookmarkUseCase: any AddBookmark
    private let updateBookmarkUseCase: any UpdateBookmark
    private let deleteBookmarkUseCase: any DeleteBookmark
    private let moveBookmarksUseCase: any MoveBookmarks
    private let normalizeBookmarkOrderUseCase: any NormalizeBookmarkOrder
    private let loadPresetsUseCase: any LoadPresets
    private let savePresetUseCase: any SavePreset
    private let overwritePresetUseCase: any OverwritePreset
    private let renamePresetUseCase: any RenamePreset
    private let deletePresetUseCase: any DeletePreset
    private let errorHandler: ErrorHandler

    public private(set) var bookmarks: [Bookmark] = []
    public private(set) var presets: [Preset] = []
    public var searchText: String = ""

    public init(
        loadBookmarks: any LoadBookmarks,
        addBookmark: any AddBookmark,
        updateBookmark: any UpdateBookmark,
        deleteBookmark: any DeleteBookmark,
        moveBookmarks: any MoveBookmarks,
        normalizeBookmarkOrder: any NormalizeBookmarkOrder,
        loadPresets: any LoadPresets,
        savePreset: any SavePreset,
        overwritePreset: any OverwritePreset,
        renamePreset: any RenamePreset,
        deletePreset: any DeletePreset,
        errorHandler: ErrorHandler
    ) {
        self.loadBookmarksUseCase = loadBookmarks
        self.addBookmarkUseCase = addBookmark
        self.updateBookmarkUseCase = updateBookmark
        self.deleteBookmarkUseCase = deleteBookmark
        self.moveBookmarksUseCase = moveBookmarks
        self.normalizeBookmarkOrderUseCase = normalizeBookmarkOrder
        self.loadPresetsUseCase = loadPresets
        self.savePresetUseCase = savePreset
        self.overwritePresetUseCase = overwritePreset
        self.renamePresetUseCase = renamePreset
        self.deletePresetUseCase = deletePreset
        self.errorHandler = errorHandler
    }

    // MARK: - Loading

    /// Reloads both lists; on failure the previous data is kept (stale beats blank).
    public func load() {
        do {
            bookmarks = try loadBookmarksUseCase()
            presets = try loadPresetsUseCase()
        } catch {
            errorHandler.showPersistenceError(error)
        }
    }

    /// One-time legacy repair of duplicate bookmark sort indexes.
    public func normalizeBookmarkOrder() {
        do {
            try normalizeBookmarkOrderUseCase()
            bookmarks = try loadBookmarksUseCase()
        } catch {
            errorHandler.showPersistenceError(error)
        }
    }

    // MARK: - Filtering

    public var filteredBookmarks: [Bookmark] {
        guard !searchText.isEmpty else { return bookmarks }
        let query = searchText.lowercased()
        return bookmarks.filter {
            $0.title.lowercased().contains(query) ||
            $0.urlString.lowercased().contains(query)
        }
    }

    public var filteredPresets: [Preset] {
        guard !searchText.isEmpty else { return presets }
        let query = searchText.lowercased()
        return presets.filter { $0.name.lowercased().contains(query) }
    }

    /// Reordering is only meaningful over the full, unfiltered list.
    public var canReorderBookmarks: Bool { searchText.isEmpty }

    // MARK: - Bookmark mutations

    public func addBookmark(urlString: String, title: String?) {
        do {
            if try addBookmarkUseCase(urlString: urlString, title: title) == nil {
                errorHandler.showToast(String(localized: "Nothing to bookmark yet"))
            }
            load()
        } catch {
            errorHandler.showPersistenceError(error)
        }
    }

    public func updateBookmark(_ bookmark: Bookmark, title: String, urlString: String) {
        do {
            try updateBookmarkUseCase(bookmark, title: title, urlString: urlString)
            load()
        } catch {
            errorHandler.showPersistenceError(error)
        }
    }

    public func deleteBookmark(_ bookmark: Bookmark) {
        do {
            try deleteBookmarkUseCase(bookmark)
            load()
        } catch {
            errorHandler.showPersistenceError(error)
        }
    }

    public func moveBookmarks(from source: IndexSet, to destination: Int) {
        do {
            try moveBookmarksUseCase(bookmarks, from: source, to: destination)
            load()
        } catch {
            errorHandler.showPersistenceError(error)
        }
    }

    // MARK: - Preset mutations

    public func savePreset(named name: String?, rows: Int, cols: Int, urls: [String]) {
        do {
            try savePresetUseCase(named: name, rows: rows, cols: cols, urls: urls)
            load()
        } catch {
            errorHandler.showPersistenceError(error)
        }
    }

    public func overwritePreset(_ preset: Preset, rows: Int, cols: Int, urls: [String]) {
        do {
            try overwritePresetUseCase(preset, rows: rows, cols: cols, urls: urls)
            load()
        } catch {
            errorHandler.showPersistenceError(error)
        }
    }

    public func renamePreset(_ preset: Preset, to name: String) {
        do {
            try renamePresetUseCase(preset, to: name)
            load()
        } catch {
            errorHandler.showPersistenceError(error)
        }
    }

    public func deletePreset(_ preset: Preset) {
        do {
            try deletePresetUseCase(preset)
            load()
        } catch {
            errorHandler.showPersistenceError(error)
        }
    }
}
