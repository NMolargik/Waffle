//
//  SidebarModelTests.swift
//  WaffleFeatureSidebarTests
//
//  Behavior tests for the sidebar view model over fake use-cases: loading, search
//  filtering, mutation routing, and error/toast surfacing through the ErrorHandler.
//

import Foundation
import Testing
import WaffleCore
import WaffleDesignSystem
@testable import WaffleFeatureSidebar

/// Shared mutable backing store the fake use-cases read and write.
@MainActor
private final class FakeLibrary {
    var bookmarks: [Bookmark] = []
    var presets: [Preset] = []
    var errorToThrow: PersistenceError?
    private(set) var normalizeCalls = 0
    private(set) var movedBookmarks: [(IndexSet, Int)] = []
    private(set) var deletedPresets: [Preset] = []

    struct LoadB: LoadBookmarks {
        let lib: FakeLibrary
        func callAsFunction() throws(PersistenceError) -> [Bookmark] {
            if let error = lib.errorToThrow { throw error }
            return lib.bookmarks
        }
    }
    struct AddB: AddBookmark {
        let lib: FakeLibrary
        @discardableResult
        func callAsFunction(urlString: String, title: String?) throws(PersistenceError) -> Bookmark? {
            if let error = lib.errorToThrow { throw error }
            let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, let url = URL(string: trimmed) else { return nil }
            let bookmark = Bookmark(url: url, title: title ?? "")
            lib.bookmarks.append(bookmark)
            return bookmark
        }
    }
    struct UpdateB: UpdateBookmark {
        let lib: FakeLibrary
        func callAsFunction(_ bookmark: Bookmark, title: String, urlString: String) throws(PersistenceError) {
            if let error = lib.errorToThrow { throw error }
            bookmark.title = title
            bookmark.urlString = urlString
        }
    }
    struct DeleteB: DeleteBookmark {
        let lib: FakeLibrary
        func callAsFunction(_ bookmark: Bookmark) throws(PersistenceError) {
            if let error = lib.errorToThrow { throw error }
            lib.bookmarks.removeAll { $0.id == bookmark.id }
        }
    }
    struct MoveB: MoveBookmarks {
        let lib: FakeLibrary
        func callAsFunction(_ ordered: [Bookmark], from source: IndexSet, to destination: Int) throws(PersistenceError) {
            if let error = lib.errorToThrow { throw error }
            lib.movedBookmarks.append((source, destination))
            lib.bookmarks = GridLayout.moved(ordered, fromOffsets: source, toOffset: destination)
        }
    }
    struct NormalizeB: NormalizeBookmarkOrder {
        let lib: FakeLibrary
        func callAsFunction() throws(PersistenceError) {
            if let error = lib.errorToThrow { throw error }
            lib.normalizeCalls += 1
        }
    }
    struct LoadP: LoadPresets {
        let lib: FakeLibrary
        func callAsFunction() throws(PersistenceError) -> [Preset] {
            if let error = lib.errorToThrow { throw error }
            return lib.presets
        }
    }
    struct SaveP: SavePreset {
        let lib: FakeLibrary
        @discardableResult
        func callAsFunction(named name: String?, rows: Int, cols: Int, urls: [String], now: Date) throws(PersistenceError) -> Preset {
            if let error = lib.errorToThrow { throw error }
            let preset = Preset(name: name ?? "Preset", rows: rows, cols: cols, urls: urls)
            lib.presets.insert(preset, at: 0)
            return preset
        }
    }
    struct OverwriteP: OverwritePreset {
        let lib: FakeLibrary
        func callAsFunction(_ preset: Preset, rows: Int, cols: Int, urls: [String]) throws(PersistenceError) {
            if let error = lib.errorToThrow { throw error }
            preset.rows = rows
            preset.cols = cols
            preset.urls = urls
        }
    }
    struct RenameP: RenamePreset {
        let lib: FakeLibrary
        func callAsFunction(_ preset: Preset, to name: String) throws(PersistenceError) {
            if let error = lib.errorToThrow { throw error }
            preset.name = name
        }
    }
    struct DeleteP: DeletePreset {
        let lib: FakeLibrary
        func callAsFunction(_ preset: Preset) throws(PersistenceError) {
            if let error = lib.errorToThrow { throw error }
            lib.deletedPresets.append(preset)
            lib.presets.removeAll { $0.id == preset.id }
        }
    }

    func makeModel(errorHandler: ErrorHandler = ErrorHandler()) -> SidebarModel {
        SidebarModel(
            loadBookmarks: LoadB(lib: self),
            addBookmark: AddB(lib: self),
            updateBookmark: UpdateB(lib: self),
            deleteBookmark: DeleteB(lib: self),
            moveBookmarks: MoveB(lib: self),
            normalizeBookmarkOrder: NormalizeB(lib: self),
            loadPresets: LoadP(lib: self),
            savePreset: SaveP(lib: self),
            overwritePreset: OverwriteP(lib: self),
            renamePreset: RenameP(lib: self),
            deletePreset: DeleteP(lib: self),
            errorHandler: errorHandler
        )
    }
}

@Suite("SidebarModel")
@MainActor
struct SidebarModelTests {

    private func bookmark(_ title: String, _ url: String) -> Bookmark {
        Bookmark(url: URL(string: url)!, title: title)
    }

    @Test("load populates both lists")
    func loadPopulates() {
        let lib = FakeLibrary()
        lib.bookmarks = [bookmark("Apple", "https://apple.com")]
        lib.presets = [Preset(name: "Dev", rows: 2, cols: 2, urls: [])]
        let model = lib.makeModel()

        model.load()

        #expect(model.bookmarks.count == 1)
        #expect(model.presets.count == 1)
    }

    @Test("load failure keeps stale data and surfaces an alert")
    func loadFailureSurfaces() {
        let lib = FakeLibrary()
        lib.bookmarks = [bookmark("Apple", "https://apple.com")]
        let errorHandler = ErrorHandler()
        let model = lib.makeModel(errorHandler: errorHandler)
        model.load()
        #expect(model.bookmarks.count == 1)

        lib.errorToThrow = .fetchFailed("disk full")
        lib.bookmarks = []
        model.load()

        #expect(model.bookmarks.count == 1)          // stale beats blank
        #expect(errorHandler.currentError != nil)
    }

    @Test("search filters bookmarks by title and URL, presets by name")
    func searchFilters() {
        let lib = FakeLibrary()
        lib.bookmarks = [
            bookmark("Apple", "https://apple.com"),
            bookmark("News", "https://news.ycombinator.com"),
        ]
        lib.presets = [
            Preset(name: "Dev", rows: 1, cols: 1, urls: []),
            Preset(name: "News", rows: 1, cols: 1, urls: []),
        ]
        let model = lib.makeModel()
        model.load()

        model.searchText = "news"

        #expect(model.filteredBookmarks.map(\.title) == ["News"])
        #expect(model.filteredPresets.map(\.name) == ["News"])
        #expect(!model.canReorderBookmarks)          // no drag-reorder while filtered

        model.searchText = "ycombinator"
        #expect(model.filteredBookmarks.count == 1)  // URL matches too
    }

    @Test("adding an invalid bookmark shows the 'nothing to bookmark' toast")
    func addInvalidBookmarkToasts() {
        let lib = FakeLibrary()
        let errorHandler = ErrorHandler()
        let model = lib.makeModel(errorHandler: errorHandler)

        model.addBookmark(urlString: "   ", title: "Nope")

        #expect(model.bookmarks.isEmpty)
        #expect(errorHandler.toastMessage != nil)
        #expect(errorHandler.currentError == nil)    // invalid input is not a data error
    }

    @Test("mutations route through use-cases and reload")
    func mutationsRouteAndReload() {
        let lib = FakeLibrary()
        let model = lib.makeModel()

        model.addBookmark(urlString: "https://apple.com", title: "Apple")
        #expect(model.bookmarks.count == 1)

        model.savePreset(named: "Dev", rows: 2, cols: 2, urls: ["https://apple.com"])
        #expect(model.presets.map(\.name) == ["Dev"])

        model.deletePreset(model.presets[0])
        #expect(lib.deletedPresets.count == 1)
        #expect(model.presets.isEmpty)

        model.moveBookmarks(from: IndexSet(integer: 0), to: 1)
        #expect(lib.movedBookmarks.count == 1)
    }

    @Test("save failures surface as data errors")
    func saveFailureSurfaces() {
        let lib = FakeLibrary()
        let errorHandler = ErrorHandler()
        let model = lib.makeModel(errorHandler: errorHandler)

        lib.errorToThrow = .saveFailed("disk full")
        model.savePreset(named: "Dev", rows: 1, cols: 1, urls: [])

        #expect(errorHandler.currentError != nil)
    }

    @Test("normalizeBookmarkOrder runs the repair use-case")
    func normalizeRuns() {
        let lib = FakeLibrary()
        let model = lib.makeModel()
        model.normalizeBookmarkOrder()
        #expect(lib.normalizeCalls == 1)
    }
}
