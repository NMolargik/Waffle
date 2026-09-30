//
//  SessionControllerTests.swift
//  WaffleCompositionTests
//
//  Ported from the old WaffleCoordinatorTests: entitlement gating, gated actions, and
//  deep-link routing over a real (on-disk, CloudKit-free) container with a fake
//  entitlement provider — Syrup gating is now testable without StoreKit.
//

import Foundation
import SwiftData
import Testing
import WaffleCore
@testable import WaffleComposition

@MainActor
private final class FakeEntitlements: EntitlementProviding {
    var isPurchased: Bool
    init(isPurchased: Bool = false) { self.isPurchased = isPurchased }
}

@MainActor
private final class FakePresetDonator: PresetDonating {
    private(set) var donated: [Preset] = []
    func donateOpenPreset(_ preset: Preset) { donated.append(preset) }
}

private final class FakeKeyValueStore: KeyValueStoring {
    private(set) var storage: [String: Any] = [:]

    func data(forKey defaultName: String) -> Data? { storage[defaultName] as? Data }
    func string(forKey defaultName: String) -> String? { storage[defaultName] as? String }
    func bool(forKey defaultName: String) -> Bool { storage[defaultName] as? Bool ?? false }
    func integer(forKey defaultName: String) -> Int { storage[defaultName] as? Int ?? 0 }
    func set(_ value: Any?, forKey defaultName: String) { storage[defaultName] = value }
    func removeObject(forKey defaultName: String) { storage.removeValue(forKey: defaultName) }
}

/// Serialized: each test owns a SwiftData container (see LibraryRepositoryTests).
@Suite("SessionController", .serialized)
@MainActor
struct SessionControllerTests {

    private func makeSession(
        purchased: Bool = false,
        donator: FakePresetDonator? = nil
    ) throws -> SessionController {
        let storeURL = URL.temporaryDirectory.appending(path: "waffle-test-\(UUID().uuidString).store")
        let config = ModelConfiguration(url: storeURL, cloudKitDatabase: .none)
        let container = try ModelContainer(for: Bookmark.self, Preset.self, configurations: config)
        return SessionController(
            container: container,
            defaults: FakeKeyValueStore(),
            entitlements: FakeEntitlements(isPurchased: purchased),
            presetDonator: donator
        )
    }

    // MARK: - Entitlement gating

    @Test func freeUserGridIsClampedAndUpsold() throws {
        let session = try makeSession()
        session.grid.makeInitialItem()

        session.setGridSize(rows: 4, cols: 4)

        #expect(session.grid.rowCount == AppConfiguration.maxFreeRows)
        #expect(session.grid.colCount == AppConfiguration.maxFreeCols)
        #expect(session.presentSyrupSheet)
    }

    @Test func freeUserWithinLimitsIsNotUpsold() throws {
        let session = try makeSession()
        session.grid.makeInitialItem()

        session.setGridSize(rows: 2, cols: 2)

        #expect(session.grid.rowCount == 2)
        #expect(!session.presentSyrupSheet)
    }

    @Test func premiumUserGetsPremiumLimits() throws {
        let session = try makeSession(purchased: true)
        session.grid.makeInitialItem()

        session.setGridSize(rows: 4, cols: 4)

        #expect(session.grid.rowCount == AppConfiguration.maxPremiumRows)
        #expect(session.grid.colCount == AppConfiguration.maxPremiumCols)
        #expect(!session.presentSyrupSheet)
    }

    @Test func applyPresetIsGatedBehindSyrup() throws {
        let session = try makeSession()
        let preset = try session.savePreset(named: "P", rows: 2, cols: 2, urls: ["https://apple.com"])

        let applied = session.applyPreset(preset)

        #expect(!applied)
        #expect(session.presentSyrupSheet)
    }

    @Test func premiumApplyPresetAppliesAndDonates() throws {
        let donator = FakePresetDonator()
        let session = try makeSession(purchased: true, donator: donator)
        let preset = try session.savePreset(named: "P", rows: 2, cols: 2, urls: ["https://apple.com"])

        let applied = session.applyPreset(preset)

        #expect(applied)
        #expect(session.grid.rowCount == 2)
        #expect(donator.donated.map(\.id) == [preset.id])
        #expect(!session.presentSyrupSheet)
    }

    // MARK: - Deep links

    @Test func openBookmarkDeepLinkLoadsSelectedCell() throws {
        let session = try makeSession()
        let bookmark = try #require(try session.addBookmark(urlString: "https://apple.com", title: "Apple"))

        session.handle(.openBookmark(bookmark.id))

        #expect(session.grid.addressText == "https://apple.com")
        #expect(session.grid.selectedCell?.address == "https://apple.com")
    }

    @Test func unknownPresetDeepLinkShowsToast() throws {
        let session = try makeSession()
        session.handle(.openPreset(UUID()))
        #expect(session.errorHandler.toastMessage != nil)
        #expect(!session.presentSyrupSheet)
    }

    @Test func openURLDeepLinkBootstrapsGridWhenEmpty() throws {
        let session = try makeSession()
        session.handle(.openURL(URL(string: "https://swift.org")!))
        #expect(session.grid.selectedCell != nil)
        #expect(session.grid.addressText == "https://swift.org")
    }

    @Test func gridDeepLinkResizesWithinFreeLimits() throws {
        let session = try makeSession()
        session.grid.makeInitialItem()
        session.handle(.setGrid(rows: 2, cols: 2))
        #expect(session.grid.rowCount == 2)
        #expect(session.grid.colCount == 2)
    }

    // MARK: - Factories

    @Test func factoriesShareTheSessionGraph() throws {
        let session = try makeSession()
        let sidebar = session.makeSidebarModel()

        sidebar.addBookmark(urlString: "https://apple.com", title: "Apple")

        // The sidebar wrote through the same repository the session's use-cases read.
        #expect(try session.loadBookmarks().count == 1)
    }
}
