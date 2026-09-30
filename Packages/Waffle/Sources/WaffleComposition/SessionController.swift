//
//  SessionController.swift
//  WaffleComposition
//
//  The composition root. Builds the whole dependency graph (container → repositories →
//  use-cases → change center → store) and owns the app-wide policy the old
//  WaffleCoordinator held: entitlement gating, gated actions, deep-link routing, the
//  Syrup sheet flag, and the one-primary-window count. Screens get their view models
//  from the `make…Model()` factories; App Intents reach persistence through the
//  use-case properties — never a repository directly.
//

import Foundation
import Observation
import SwiftData
import WaffleCore
import WaffleData
import WaffleDesignSystem
import WaffleFeatureGrid
import WaffleFeatureSidebar
import WaffleFeatureSettings
import WaffleServices

@MainActor
@Observable
public final class SessionController {

    // MARK: - Graph

    public let container: ModelContainer
    public let errorHandler: ErrorHandler
    public let store: StoreManager
    public let grid: GridModel

    private let entitlements: any EntitlementProviding
    private let presetDonator: (any PresetDonating)?
    private let indexer: (any LibraryIndexing)?
    private let activityAnnotator: (any BrowsingActivityAnnotating)?

    // Bookmark use-cases
    public let loadBookmarks: any LoadBookmarks
    public let findBookmark: any FindBookmark
    public let addBookmark: any AddBookmark
    public let updateBookmark: any UpdateBookmark
    public let deleteBookmark: any DeleteBookmark
    public let moveBookmarks: any MoveBookmarks
    public let deleteAllBookmarks: any DeleteAllBookmarks
    public let normalizeBookmarkOrder: any NormalizeBookmarkOrder

    // Preset use-cases
    public let loadPresets: any LoadPresets
    public let findPreset: any FindPreset
    public let savePreset: any SavePreset
    public let overwritePreset: any OverwritePreset
    public let renamePreset: any RenamePreset
    public let deletePreset: any DeletePreset
    public let deleteAllPresets: any DeleteAllPresets

    public let observeLibraryChanges: any ObserveLibraryChanges

    // MARK: - App-wide state

    public var presentSyrupSheet = false

    /// Number of main-window scenes currently hosting the browsing UI.
    /// Runtime-only (never persisted): a `WebPage` crashes WebKit when hosted by two
    /// `WebView`s, so only the scene that claims this may show the grid, and detached
    /// windows reopen the main window only when it's 0.
    public var mainWindowCount = 0

    @ObservationIgnored
    private var indexObservationTask: Task<Void, Never>?

    // MARK: - Init

    public init(
        container: ModelContainer? = nil,
        defaults: any KeyValueStoring = UserDefaults.standard,
        entitlements: (any EntitlementProviding)? = nil,
        presetDonator: (any PresetDonating)? = nil,
        indexer: (any LibraryIndexing)? = nil,
        activityAnnotator: (any BrowsingActivityAnnotating)? = nil
    ) {
        let container = container ?? WaffleStore.makeContainer()
        self.container = container
        self.errorHandler = ErrorHandler()
        self.grid = GridModel(defaults: defaults)
        self.presetDonator = presetDonator
        self.indexer = indexer
        self.activityAnnotator = activityAnnotator

        let store = StoreManager()
        self.store = store
        self.entitlements = entitlements ?? store

        let changeCenter = LibraryChangeCenter()
        let bookmarkRepository = DefaultBookmarkRepository(container: container, changeCenter: changeCenter)
        let presetRepository = DefaultPresetRepository(container: container, changeCenter: changeCenter)

        loadBookmarks = LoadBookmarksUseCase(repository: bookmarkRepository)
        findBookmark = FindBookmarkUseCase(repository: bookmarkRepository)
        addBookmark = AddBookmarkUseCase(repository: bookmarkRepository)
        updateBookmark = UpdateBookmarkUseCase(repository: bookmarkRepository)
        deleteBookmark = DeleteBookmarkUseCase(repository: bookmarkRepository)
        moveBookmarks = MoveBookmarksUseCase(repository: bookmarkRepository)
        deleteAllBookmarks = DeleteAllBookmarksUseCase(repository: bookmarkRepository)
        normalizeBookmarkOrder = NormalizeBookmarkOrderUseCase(repository: bookmarkRepository)

        loadPresets = LoadPresetsUseCase(repository: presetRepository)
        findPreset = FindPresetUseCase(repository: presetRepository)
        savePreset = SavePresetUseCase(repository: presetRepository)
        overwritePreset = OverwritePresetUseCase(repository: presetRepository)
        renamePreset = RenamePresetUseCase(repository: presetRepository)
        deletePreset = DeletePresetUseCase(repository: presetRepository)
        deleteAllPresets = DeleteAllPresetsUseCase(repository: presetRepository)

        observeLibraryChanges = ObserveLibraryChangesUseCase(center: changeCenter)

        startIndexObservation()
    }

    deinit {
        indexObservationTask?.cancel()
    }

    // MARK: - Entitlements

    public var isSyrupEnabled: Bool { entitlements.isPurchased }

    public var canUseRearrange: Bool { isSyrupEnabled }
    public var canUsePopout: Bool { isSyrupEnabled }
    public var canUseFullscreen: Bool { isSyrupEnabled }
    public var canMakePresets: Bool { isSyrupEnabled }

    public var maxRows: Int { isSyrupEnabled ? AppConfiguration.maxPremiumRows : AppConfiguration.maxFreeRows }
    public var maxCols: Int { isSyrupEnabled ? AppConfiguration.maxPremiumCols : AppConfiguration.maxFreeCols }

    public func requestSyrup() {
        presentSyrupSheet = true
    }

    // MARK: - Gated actions

    /// Applies a preset if the user has Syrup; otherwise presents the upsell.
    /// - Returns: true when the preset was applied.
    @discardableResult
    public func applyPreset(_ preset: Preset) -> Bool {
        guard canMakePresets else {
            requestSyrup()
            return false
        }
        grid.apply(preset: preset, maxRows: maxRows, maxCols: maxCols)
        // Donate so Siri learns which presets the user reaches for.
        presetDonator?.donateOpenPreset(preset)
        return true
    }

    /// Resizes the grid, presenting the upsell when the request exceeds free limits.
    public func setGridSize(rows: Int, cols: Int) {
        if !isSyrupEnabled && (rows > maxRows || cols > maxCols) {
            requestSyrup()
        }
        grid.setGridSize(rows: rows, cols: cols, maxRows: maxRows, maxCols: maxCols)
    }

    /// Bookmarks the selected cell's page (menu bar / keyboard action).
    public func bookmarkSelectedPage() {
        guard let cell = grid.selectedCell, !cell.address.isEmpty else { return }
        do {
            if try addBookmark(urlString: cell.address, title: cell.page.title) == nil {
                errorHandler.showToast(String(localized: "Nothing to bookmark yet"))
            }
        } catch {
            errorHandler.showPersistenceError(error)
        }
    }

    /// Saves the current grid as a quick preset, gated behind Syrup (menu bar action).
    public func saveCurrentGridAsPreset() {
        guard canMakePresets else {
            requestSyrup()
            return
        }
        do {
            try savePreset(named: nil, rows: grid.rowCount, cols: grid.colCount, urls: grid.flattenedAddresses())
        } catch {
            errorHandler.showPersistenceError(error)
        }
    }

    // MARK: - Deep links

    /// Routes a parsed deep link (from App Intents, Spotlight, or external apps).
    public func handle(_ link: DeepLink) {
        switch link {
        case .openPreset(let id):
            let preset: Preset?
            do {
                preset = try findPreset(id: id)
            } catch {
                errorHandler.showPersistenceError(error)
                return
            }
            guard let preset else {
                errorHandler.showToast(String(localized: "That preset is no longer available"))
                return
            }
            applyPreset(preset)

        case .openBookmark(let id):
            let bookmark: Bookmark?
            do {
                bookmark = try findBookmark(id: id)
            } catch {
                errorHandler.showPersistenceError(error)
                return
            }
            guard let bookmark, bookmark.url != nil else {
                errorHandler.showToast(String(localized: "That bookmark is no longer available"))
                return
            }
            if grid.selectedCell == nil {
                grid.makeInitialItem()
            }
            grid.loadInSelectedCell(bookmark.urlString)

        case .setGrid(let rows, let cols):
            setGridSize(rows: rows, cols: cols)

        case .openURL(let url):
            if grid.selectedCell == nil {
                grid.makeInitialItem()
            }
            grid.loadInSelectedCell(url.absoluteString)
        }
    }

    // MARK: - Browsing activity

    /// Annotates the Handoff/Spotlight user activity when the current page matches a
    /// saved bookmark (a read for system integration — failures are non-fatal).
    public func annotateBrowsingActivity(_ activity: NSUserActivity, forAddress address: String) {
        guard let activityAnnotator,
              let bookmark = (try? loadBookmarks())?.first(where: { $0.urlString == address })
        else { return }
        activityAnnotator.annotate(activity, matching: bookmark)
    }

    // MARK: - Spotlight index

    /// Rebuilds the semantic index; also run at launch to cover items synced via
    /// CloudKit while the app wasn't running.
    public func reindexLibrary() {
        guard let indexer,
              let presets = try? loadPresets(),
              let bookmarks = try? loadBookmarks()
        else { return }
        indexer.reindex(presets: presets, bookmarks: bookmarks)
    }

    private func startIndexObservation() {
        guard indexer != nil else { return }
        indexObservationTask = Task { [weak self] in
            guard let stream = self?.observeLibraryChanges() else { return }
            for await _ in stream {
                guard let self else { return }
                self.reindexLibrary()
            }
        }
    }

    // MARK: - View-model factories

    public func makeSidebarModel() -> SidebarModel {
        SidebarModel(
            loadBookmarks: loadBookmarks,
            addBookmark: addBookmark,
            updateBookmark: updateBookmark,
            deleteBookmark: deleteBookmark,
            moveBookmarks: moveBookmarks,
            normalizeBookmarkOrder: normalizeBookmarkOrder,
            loadPresets: loadPresets,
            savePreset: savePreset,
            overwritePreset: overwritePreset,
            renamePreset: renamePreset,
            deletePreset: deletePreset,
            errorHandler: errorHandler
        )
    }

    public func makeSettingsModel() -> SettingsModel {
        SettingsModel(
            deleteAllBookmarks: deleteAllBookmarks,
            deleteAllPresets: deleteAllPresets,
            addBookmark: addBookmark,
            savePreset: savePreset,
            errorHandler: errorHandler
        )
    }
}
