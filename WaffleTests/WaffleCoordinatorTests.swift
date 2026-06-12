//
//  WaffleCoordinatorTests.swift
//  WaffleTests
//

import Foundation
import SwiftData
import Testing
@testable import Waffle

/// Serialized: each test owns a SwiftData container (see LibraryManagerTests).
@Suite("WaffleCoordinator", .serialized)
@MainActor
struct WaffleCoordinatorTests {
    private func makeCoordinator() throws -> (WaffleCoordinator, FakeKeyValueStore) {
        let storeURL = URL.temporaryDirectory.appending(path: "waffle-test-\(UUID().uuidString).store")
        let config = ModelConfiguration(url: storeURL, cloudKitDatabase: .none)
        let container = try ModelContainer(for: Bookmark.self, Preset.self, configurations: config)
        let errorHandler = ErrorHandler()
        let defaults = FakeKeyValueStore()
        let coordinator = WaffleCoordinator(
            store: StoreManager(),
            library: LibraryManager(container: container, errorHandler: errorHandler),
            errorHandler: errorHandler,
            waffleState: WaffleState(defaults: defaults)
        )
        return (coordinator, defaults)
    }

    // MARK: - Entitlement gating (StoreKit defaults to not purchased in tests)

    @Test func freeUserGridIsClampedAndUpsold() throws {
        let (coordinator, _) = try makeCoordinator()
        coordinator.waffleState.makeInitialItem()

        coordinator.setGridSize(rows: 4, cols: 4)

        #expect(coordinator.waffleState.rowCount == AppConfiguration.maxFreeRows)
        #expect(coordinator.waffleState.colCount == AppConfiguration.maxFreeCols)
        #expect(coordinator.presentSyrupSheet)
    }

    @Test func freeUserWithinLimitsIsNotUpsold() throws {
        let (coordinator, _) = try makeCoordinator()
        coordinator.waffleState.makeInitialItem()

        coordinator.setGridSize(rows: 2, cols: 2)

        #expect(coordinator.waffleState.rowCount == 2)
        #expect(!coordinator.presentSyrupSheet)
    }

    @Test func applyPresetIsGatedBehindSyrup() throws {
        let (coordinator, _) = try makeCoordinator()
        let preset = coordinator.library.savePreset(named: "P", rows: 2, cols: 2, urls: ["https://apple.com"])

        let applied = coordinator.applyPreset(preset)

        #expect(!applied)
        #expect(coordinator.presentSyrupSheet)
    }

    // MARK: - Deep links

    @Test func openBookmarkDeepLinkLoadsSelectedCell() throws {
        let (coordinator, _) = try makeCoordinator()
        let bookmark = try #require(coordinator.library.addBookmark(urlString: "https://apple.com", title: "Apple"))

        coordinator.handle(.openBookmark(bookmark.id))

        #expect(coordinator.waffleState.addressText == "https://apple.com")
        #expect(coordinator.waffleState.selectedCell?.address == "https://apple.com")
    }

    @Test func unknownPresetDeepLinkShowsToast() throws {
        let (coordinator, _) = try makeCoordinator()
        coordinator.handle(.openPreset(UUID()))
        #expect(coordinator.errorHandler.toastMessage != nil)
        #expect(!coordinator.presentSyrupSheet)
    }

    @Test func openURLDeepLinkBootstrapsGridWhenEmpty() throws {
        let (coordinator, _) = try makeCoordinator()
        coordinator.handle(.openURL(URL(string: "https://swift.org")!))
        #expect(coordinator.waffleState.selectedCell != nil)
        #expect(coordinator.waffleState.addressText == "https://swift.org")
    }

    @Test func gridDeepLinkResizesWithinFreeLimits() throws {
        let (coordinator, _) = try makeCoordinator()
        coordinator.waffleState.makeInitialItem()
        coordinator.handle(.setGrid(rows: 2, cols: 2))
        #expect(coordinator.waffleState.rowCount == 2)
        #expect(coordinator.waffleState.colCount == 2)
    }
}
