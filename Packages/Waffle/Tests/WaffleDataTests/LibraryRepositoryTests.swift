//
//  LibraryRepositoryTests.swift
//  WaffleDataTests
//
//  Behavior tests for the SwiftData-backed bookmark/preset repositories, ported from the
//  old LibraryManagerTests. Serialized because each test spins up its own SwiftData
//  container; each gets a unique on-disk temp store — parallel in-memory containers
//  share a /dev/null SQLite identity and crash the host under load.
//

import Foundation
import SwiftData
import Testing
import WaffleCore
@testable import WaffleData

@Suite("Library repositories", .serialized)
@MainActor
struct LibraryRepositoryTests {

    private struct Harness {
        let container: ModelContainer
        let changeCenter = LibraryChangeCenter()
        let bookmarks: DefaultBookmarkRepository
        let presets: DefaultPresetRepository

        init() throws {
            let storeURL = URL.temporaryDirectory.appending(path: "waffle-test-\(UUID().uuidString).store")
            let config = ModelConfiguration(url: storeURL, cloudKitDatabase: .none)
            container = try ModelContainer(for: Bookmark.self, Preset.self, configurations: config)
            bookmarks = DefaultBookmarkRepository(container: container, changeCenter: changeCenter)
            presets = DefaultPresetRepository(container: container, changeCenter: changeCenter)
        }
    }

    // MARK: - Bookmarks

    @Test func addBookmarkAssignsIncrementingSortIndex() throws {
        let harness = try Harness()
        try harness.bookmarks.addBookmark(urlString: "https://a.example", title: "A")
        try harness.bookmarks.addBookmark(urlString: "https://b.example", title: "B")

        let bookmarks = try harness.bookmarks.bookmarks()
        #expect(bookmarks.map(\.title) == ["A", "B"])
        #expect(bookmarks.map(\.sortIndex) == [0, 1])
    }

    @Test func addBookmarkFallsBackToURLAsTitle() throws {
        let harness = try Harness()
        let bookmark = try harness.bookmarks.addBookmark(urlString: "https://a.example", title: "   ")
        #expect(bookmark?.title == "https://a.example")
    }

    @Test func addBookmarkRejectsEmptyURLWithoutPersisting() throws {
        let harness = try Harness()
        let bookmark = try harness.bookmarks.addBookmark(urlString: "   ", title: "Nope")
        #expect(bookmark == nil)
        #expect(try harness.bookmarks.bookmarks().isEmpty)
    }

    @Test func moveBookmarksRewritesSortIndexes() throws {
        let harness = try Harness()
        try harness.bookmarks.addBookmark(urlString: "https://a.example", title: "A")
        try harness.bookmarks.addBookmark(urlString: "https://b.example", title: "B")
        try harness.bookmarks.addBookmark(urlString: "https://c.example", title: "C")

        try harness.bookmarks.moveBookmarks(try harness.bookmarks.bookmarks(), from: IndexSet(integer: 0), to: 3)
        #expect(try harness.bookmarks.bookmarks().map(\.title) == ["B", "C", "A"])
    }

    @Test func deleteBookmarkRenumbersRemaining() throws {
        let harness = try Harness()
        try harness.bookmarks.addBookmark(urlString: "https://a.example", title: "A")
        try harness.bookmarks.addBookmark(urlString: "https://b.example", title: "B")

        try harness.bookmarks.deleteBookmark(try #require(try harness.bookmarks.bookmarks().first))
        let remaining = try harness.bookmarks.bookmarks()
        #expect(remaining.map(\.title) == ["B"])
        #expect(remaining.first?.sortIndex == 0)
    }

    @Test func bookmarkLookupByID() throws {
        let harness = try Harness()
        let added = try #require(try harness.bookmarks.addBookmark(urlString: "https://a.example", title: "A"))
        #expect(try harness.bookmarks.bookmark(id: added.id)?.title == "A")
        #expect(try harness.bookmarks.bookmark(id: UUID()) == nil)
    }

    @Test func deleteAllBookmarksEmptiesStore() throws {
        let harness = try Harness()
        try harness.bookmarks.addBookmark(urlString: "https://a.example", title: "A")
        try harness.bookmarks.deleteAllBookmarks()
        #expect(try harness.bookmarks.bookmarks().isEmpty)
    }

    // MARK: - Presets

    @Test func savePresetUsesProvidedName() throws {
        let harness = try Harness()
        let preset = try harness.presets.savePreset(named: "Morning", rows: 2, cols: 2, urls: ["https://a.example"], now: .now)
        #expect(preset.name == "Morning")
        #expect(try harness.presets.presets().count == 1)
    }

    @Test func savePresetGeneratesDefaultNameWithDate() throws {
        let harness = try Harness()
        let preset = try harness.presets.savePreset(named: "  ", rows: 1, cols: 1, urls: [], now: Date(timeIntervalSince1970: 0))
        #expect(!preset.name.trimmingCharacters(in: .whitespaces).isEmpty)
        #expect(preset.name.hasPrefix("Preset"))
    }

    @Test func overwritePresetReplacesLayout() throws {
        let harness = try Harness()
        let preset = try harness.presets.savePreset(named: "P", rows: 1, cols: 1, urls: ["https://old.example"], now: .now)
        try harness.presets.overwritePreset(preset, rows: 2, cols: 2, urls: ["https://new.example"])
        #expect(preset.rows == 2)
        #expect(preset.cols == 2)
        #expect(preset.urls == ["https://new.example"])
    }

    @Test func renamePresetIgnoresEmptyName() throws {
        let harness = try Harness()
        let preset = try harness.presets.savePreset(named: "Original", rows: 1, cols: 1, urls: [], now: .now)
        try harness.presets.renamePreset(preset, to: "   ")
        #expect(preset.name == "Original")
        try harness.presets.renamePreset(preset, to: "Renamed")
        #expect(preset.name == "Renamed")
    }

    @Test func presetLookupByID() throws {
        let harness = try Harness()
        let preset = try harness.presets.savePreset(named: "P", rows: 1, cols: 1, urls: [], now: .now)
        #expect(try harness.presets.preset(id: preset.id) === preset)
    }

    // MARK: - Change stream

    @Test func mutationsNotifyLibraryChangeStream() async throws {
        let harness = try Harness()
        var iterator = harness.changeCenter.changes().makeAsyncIterator()

        try harness.bookmarks.addBookmark(urlString: "https://a.example", title: "A")   // yield 1
        try harness.presets.savePreset(named: "P", rows: 1, cols: 1, urls: [], now: .now) // yield 2

        #expect(await iterator.next() != nil)
        #expect(await iterator.next() != nil)
    }
}
