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
private final class FakeReviewRequester: ReviewRequesting {
    private(set) var requestCount = 0
    func requestReview() { requestCount += 1 }
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
        donator: FakePresetDonator? = nil,
        reviewRequester: FakeReviewRequester? = nil
    ) throws -> SessionController {
        let storeURL = URL.temporaryDirectory.appending(path: "waffle-test-\(UUID().uuidString).store")
        let config = ModelConfiguration(url: storeURL, cloudKitDatabase: .none)
        let container = try ModelContainer(for: Bookmark.self, Preset.self, configurations: config)
        return SessionController(
            container: container,
            defaults: FakeKeyValueStore(),
            entitlements: FakeEntitlements(isPurchased: purchased),
            presetDonator: donator,
            reviewRequester: reviewRequester,
            appVersion: "1.5.0",
            blocksContent: false
        )
    }

    // MARK: - Review milestones

    @Test func secondSavedPresetRequestsReviewOnce() throws {
        let requester = FakeReviewRequester()
        let session = try makeSession(purchased: true, reviewRequester: requester)
        session.grid.makeInitialItem()

        session.saveCurrentGridAsPreset()
        #expect(requester.requestCount == 0)
        session.saveCurrentGridAsPreset()
        #expect(requester.requestCount == 1)
        session.saveCurrentGridAsPreset()
        #expect(requester.requestCount == 1)
    }

    @Test func sidebarPresetSavesCountTowardTheMilestone() throws {
        let requester = FakeReviewRequester()
        let session = try makeSession(purchased: true, reviewRequester: requester)
        let sidebar = session.makeSidebarModel()

        sidebar.savePreset(named: "One", rows: 1, cols: 1, urls: ["https://apple.com"])
        session.saveCurrentGridAsPreset()
        #expect(requester.requestCount == 1)
    }

    @Test func firstLargeGridRequestsReviewOncePerVersion() throws {
        let requester = FakeReviewRequester()
        let session = try makeSession(purchased: true, reviewRequester: requester)
        session.grid.makeInitialItem()

        session.setGridSize(rows: 2, cols: 2)
        #expect(requester.requestCount == 0)
        session.setGridSize(rows: 3, cols: 3)
        #expect(requester.requestCount == 1)
        session.setGridSize(rows: 4, cols: 4)
        #expect(requester.requestCount == 1)
        // The preset milestone is still blocked for this version.
        session.saveCurrentGridAsPreset()
        session.saveCurrentGridAsPreset()
        #expect(requester.requestCount == 1)
    }

    @Test func freeUsersNeverReachTheLargeGridMilestone() throws {
        let requester = FakeReviewRequester()
        let session = try makeSession(purchased: false, reviewRequester: requester)
        session.grid.makeInitialItem()
        session.setGridSize(rows: 3, cols: 3)
        #expect(requester.requestCount == 0)
    }

    @Test func savedPresetCarriesRefreshIntervals() throws {
        let session = try makeSession(purchased: true)
        session.grid.makeInitialItem()
        session.grid.colCount = 2
        session.grid.setRefreshInterval(.oneMinute, for: session.grid.waffleRows[0][1])

        session.saveCurrentGridAsPreset()
        let saved = try session.loadPresets().first
        #expect(saved?.refreshIntervals == [0, 60])
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

    // MARK: - Phone workspace gating

    @Test func freeUserCanAddASecondPaneButHitsThePaywallOnTheThird() throws {
        let session = try makeSession(purchased: false)
        session.grid.makeInitialItem()

        #expect(session.addPane(mode: .inner))
        #expect(session.grid.paneCount == 2)
        #expect(!session.presentSyrupSheet)

        #expect(!session.addPane(mode: .inner))
        #expect(session.grid.paneCount == 2)
        #expect(session.presentSyrupSheet)
    }

    @Test func syrupUserGetsFourPanesOnTheInnerDisplayOnly() throws {
        let session = try makeSession(purchased: true)
        session.grid.makeInitialItem()
        #expect(session.addPane(mode: .inner))
        #expect(session.addPane(mode: .inner))
        #expect(session.addPane(mode: .inner))
        #expect(session.grid.paneCount == 4)
        #expect(!session.addPane(mode: .inner))
        #expect(!session.presentSyrupSheet)

        let compact = try makeSession(purchased: true)
        compact.grid.makeInitialItem()
        #expect(compact.addPane(mode: .compact))
        #expect(!compact.addPane(mode: .compact))
        #expect(compact.grid.paneCount == 2)
        #expect(!compact.presentSyrupSheet, "a display limit is not a paywall")
    }

    @Test func freeUserSavesOneLayoutAndTheSecondShowsThePaywall() throws {
        let session = try makeSession(purchased: false)
        session.grid.makeInitialItem()
        session.addPane(mode: .compact)

        #expect(session.savePaneLayout())
        #expect(try session.loadPresets().count == 1)
        #expect(!session.presentSyrupSheet)

        #expect(!session.savePaneLayout())
        #expect(try session.loadPresets().count == 1)
        #expect(session.presentSyrupSheet)
    }

    @Test func syrupUserSavesUnlimitedLayoutsWithRatios() throws {
        let session = try makeSession(purchased: true)
        session.grid.applyPaneLayout(urls: ["https://a.example", "https://b.example", "https://c.example"], ratios: PaneRatios(primary: 0.4, stackA: 0.5, stackB: 0.7))
        #expect(session.savePaneLayout(named: "One"))
        #expect(session.savePaneLayout(named: "Two"))
        #expect(session.savePaneLayout(named: "Three"))
        let saved = try #require(try session.loadPresets().first)
        #expect(saved.paneCount == 3)
        #expect(saved.paneRatios == [0.4, 0.5, 0.7])
        #expect(saved.urls == ["https://a.example", "https://b.example", "https://c.example"])
        #expect(saved.rows == 2 && saved.cols == 2)
    }

    @Test func savedLayoutRestoresPaneCountRatiosAndURLs() throws {
        let session = try makeSession(purchased: true)
        session.grid.applyPaneLayout(urls: ["https://a.example", "https://b.example"], ratios: PaneRatios(primary: 0.3))
        session.savePaneLayout(named: "Pair")
        let preset = try #require(try session.loadPresets().first)

        session.grid.applyPaneLayout(urls: ["https://z.example"], ratios: .default)
        #expect(session.applyPaneLayout(preset, mode: .compact))
        #expect(session.grid.panes.map(\.address) == ["https://a.example", "https://b.example"])
        #expect(session.grid.paneRatios.primary == 0.3)
    }

    @Test func iPadPresetOnAPhoneOpensItsFirstPanesAndSaysSo() throws {
        let session = try makeSession(purchased: true)
        let preset = try session.savePreset(named: "Wall", rows: 3, cols: 3, urls: (0..<9).map { "https://wall.example/\($0)" })
        session.grid.makeInitialItem()

        #expect(session.applyPaneLayout(preset, mode: .compact))
        #expect(session.grid.paneCount == 2)
        #expect(session.errorHandler.toastMessage != nil)
        #expect(!session.presentSyrupSheet)
    }

    @Test func freeUserOpeningAFourPaneLayoutOnTheInnerDisplayGetsTwo() throws {
        let session = try makeSession(purchased: false)
        let preset = try session.savePreset(named: "Four", rows: 2, cols: 2, urls: (0..<4).map { "https://four.example/\($0)" }, paneCount: 4)
        #expect(session.applyPaneLayout(preset, mode: .inner))
        #expect(session.grid.paneCount == 2)
    }

    @Test func freeUserAutoRefreshAndDeskModeAreSyrup() throws {
        let free = try makeSession(purchased: false)
        #expect(!free.canUsePaneAutoRefresh && !free.canUseDeskMode)
        let paid = try makeSession(purchased: true)
        #expect(paid.canUsePaneAutoRefresh && paid.canUseDeskMode)
    }

    @Test func lapsedEntitlementTrimsRestoredPanesToTwo() throws {
        let session = try makeSession(purchased: false)
        session.grid.applyPaneLayout(urls: (0..<4).map { "https://example.com/\($0)" }, ratios: .default)
        session.adaptWorkspaceToEntitlement()
        #expect(session.grid.paneCount == 2)
    }

    @Test func ipadGatingIsUnchanged() throws {
        let free = try makeSession(purchased: false)
        #expect(free.maxRows == 2 && free.maxCols == 2)
        #expect(!free.canMakePresets)
        let paid = try makeSession(purchased: true)
        #expect(paid.maxRows == 4 && paid.maxCols == 4)
        #expect(paid.canMakePresets)
    }
}
