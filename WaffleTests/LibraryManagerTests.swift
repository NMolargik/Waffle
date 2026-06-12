//
//  LibraryManagerTests.swift
//  WaffleTests
//

import Foundation
import SwiftData
import Testing
@testable import Waffle

/// Serialized because each test spins up its own SwiftData container; giving
/// each a unique on-disk temp store avoids CoreData's shared in-memory
/// connection crashing the test host under parallel load.
@Suite("LibraryManager", .serialized)
@MainActor
struct LibraryManagerTests {
    private func makeLibrary() throws -> (LibraryManager, ModelContainer, ErrorHandler) {
        let storeURL = URL.temporaryDirectory.appending(path: "waffle-test-\(UUID().uuidString).store")
        let config = ModelConfiguration(url: storeURL, cloudKitDatabase: .none)
        let container = try ModelContainer(for: Bookmark.self, Preset.self, configurations: config)
        let errorHandler = ErrorHandler()
        return (LibraryManager(container: container, errorHandler: errorHandler), container, errorHandler)
    }

    // MARK: - Bookmarks

    @Test func addBookmarkAssignsIncrementingSortIndex() throws {
        let (library, _, _) = try makeLibrary()
        library.addBookmark(urlString: "https://a.example", title: "A")
        library.addBookmark(urlString: "https://b.example", title: "B")

        let bookmarks = library.bookmarks()
        #expect(bookmarks.map(\.title) == ["A", "B"])
        #expect(bookmarks.map(\.sortIndex) == [0, 1])
    }

    @Test func addBookmarkFallsBackToURLAsTitle() throws {
        let (library, _, _) = try makeLibrary()
        let bookmark = library.addBookmark(urlString: "https://a.example", title: "   ")
        #expect(bookmark?.title == "https://a.example")
    }

    @Test func addBookmarkRejectsEmptyURLWithToast() throws {
        let (library, _, errorHandler) = try makeLibrary()
        let bookmark = library.addBookmark(urlString: "   ", title: "Nope")
        #expect(bookmark == nil)
        #expect(library.bookmarks().isEmpty)
        #expect(errorHandler.toastMessage != nil)
    }

    @Test func moveBookmarksRewritesSortIndexes() throws {
        let (library, _, _) = try makeLibrary()
        library.addBookmark(urlString: "https://a.example", title: "A")
        library.addBookmark(urlString: "https://b.example", title: "B")
        library.addBookmark(urlString: "https://c.example", title: "C")

        library.moveBookmarks(library.bookmarks(), from: IndexSet(integer: 0), to: 3)
        #expect(library.bookmarks().map(\.title) == ["B", "C", "A"])
    }

    @Test func deleteBookmarkRenumbersRemaining() throws {
        let (library, _, _) = try makeLibrary()
        library.addBookmark(urlString: "https://a.example", title: "A")
        library.addBookmark(urlString: "https://b.example", title: "B")

        library.deleteBookmark(try #require(library.bookmarks().first))
        let remaining = library.bookmarks()
        #expect(remaining.map(\.title) == ["B"])
        #expect(remaining.first?.sortIndex == 0)
    }

    @Test func bookmarkLookupByID() throws {
        let (library, _, _) = try makeLibrary()
        let added = try #require(library.addBookmark(urlString: "https://a.example", title: "A"))
        #expect(library.bookmark(id: added.id)?.title == "A")
        #expect(library.bookmark(id: UUID()) == nil)
    }

    @Test func deleteAllBookmarksEmptiesStoreAndToasts() throws {
        let (library, _, errorHandler) = try makeLibrary()
        library.addBookmark(urlString: "https://a.example", title: "A")
        library.deleteAllBookmarks()
        #expect(library.bookmarks().isEmpty)
        #expect(errorHandler.toastMessage != nil)
    }

    // MARK: - Presets

    @Test func savePresetUsesProvidedName() throws {
        let (library, _, _) = try makeLibrary()
        let preset = library.savePreset(named: "Morning", rows: 2, cols: 2, urls: ["https://a.example"])
        #expect(preset.name == "Morning")
        #expect(library.presets().count == 1)
    }

    @Test func savePresetGeneratesDefaultNameWithDate() throws {
        let (library, _, _) = try makeLibrary()
        let preset = library.savePreset(named: "  ", rows: 1, cols: 1, urls: [], now: Date(timeIntervalSince1970: 0))
        #expect(!preset.name.trimmingCharacters(in: .whitespaces).isEmpty)
        #expect(preset.name.hasPrefix("Preset"))
    }

    @Test func overwritePresetReplacesLayout() throws {
        let (library, _, _) = try makeLibrary()
        let preset = library.savePreset(named: "P", rows: 1, cols: 1, urls: ["https://old.example"])
        library.overwritePreset(preset, rows: 2, cols: 2, urls: ["https://new.example"])
        #expect(preset.rows == 2)
        #expect(preset.cols == 2)
        #expect(preset.urls == ["https://new.example"])
    }

    @Test func renamePresetIgnoresEmptyName() throws {
        let (library, _, _) = try makeLibrary()
        let preset = library.savePreset(named: "Original", rows: 1, cols: 1, urls: [])
        library.renamePreset(preset, to: "   ")
        #expect(preset.name == "Original")
        library.renamePreset(preset, to: "Renamed")
        #expect(preset.name == "Renamed")
    }

    @Test func presetLookupByID() throws {
        let (library, _, _) = try makeLibrary()
        let preset = library.savePreset(named: "P", rows: 1, cols: 1, urls: [])
        #expect(library.preset(id: preset.id) === preset)
    }

    @Test func libraryDidChangeFiresOnMutation() throws {
        let (library, _, _) = try makeLibrary()
        var changeCount = 0
        library.libraryDidChange = { changeCount += 1 }
        library.addBookmark(urlString: "https://a.example", title: "A")
        library.savePreset(named: "P", rows: 1, cols: 1, urls: [])
        #expect(changeCount == 2)
    }
}
