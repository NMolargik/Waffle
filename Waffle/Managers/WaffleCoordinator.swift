//
//  WaffleCoordinator.swift
//  Waffle
//
//  Created by Nick Molargik on 9/2/25.
//

import AppIntents
import Foundation

/// App-wide coordinator: owns grid state, entitlement gating, deep-link
/// routing, and error surfacing.
@Observable
@MainActor
final class WaffleCoordinator {
    let waffleState: WaffleState
    let store: StoreManager
    let library: LibraryManager
    let errorHandler: ErrorHandler

    var presentSyrupSheet = false

    /// Number of main-window scenes currently hosting the browsing UI.
    /// Runtime-only (never persisted): a `WebPage` crashes WebKit when hosted
    /// by two `WebView`s, so only the scene that claims this may show the
    /// grid, and detached windows reopen the main window only when it's 0.
    var mainWindowCount = 0

    init(
        store: StoreManager,
        library: LibraryManager,
        errorHandler: ErrorHandler,
        waffleState: WaffleState
    ) {
        self.store = store
        self.library = library
        self.errorHandler = errorHandler
        self.waffleState = waffleState
    }

    // MARK: - Entitlements

    var isSyrupEnabled: Bool {
        store.isPurchased
    }

    var canUseRearrange: Bool { isSyrupEnabled }
    var canUsePopout: Bool { isSyrupEnabled }
    var canUseFullscreen: Bool { isSyrupEnabled }
    var canMakePresets: Bool { isSyrupEnabled }

    var maxRows: Int { isSyrupEnabled ? AppConfiguration.maxPremiumRows : AppConfiguration.maxFreeRows }
    var maxCols: Int { isSyrupEnabled ? AppConfiguration.maxPremiumCols : AppConfiguration.maxFreeCols }

    func requestSyrup() {
        presentSyrupSheet = true
    }

    // MARK: - Gated Actions

    /// Applies a preset if the user has Syrup; otherwise presents the upsell.
    /// - Returns: true when the preset was applied.
    @discardableResult
    func applyPreset(_ preset: Preset) -> Bool {
        guard canMakePresets else {
            requestSyrup()
            return false
        }
        waffleState.apply(preset: preset, maxRows: maxRows, maxCols: maxCols)
        donateOpenPreset(preset)
        return true
    }

    /// Donates the matching intent so Siri learns which presets the user
    /// reaches for and can suggest them proactively.
    private func donateOpenPreset(_ preset: Preset) {
        let intent = OpenPresetIntent()
        intent.preset = PresetEntity(preset: preset)
        intent.donate()
    }

    /// Resizes the grid, presenting the upsell when the request exceeds free limits.
    func setGridSize(rows: Int, cols: Int) {
        if !isSyrupEnabled && (rows > maxRows || cols > maxCols) {
            requestSyrup()
        }
        waffleState.setGridSize(rows: rows, cols: cols, maxRows: maxRows, maxCols: maxCols)
    }

    // MARK: - Deep Links

    /// Routes a parsed deep link (from App Intents, Spotlight, or external apps).
    func handle(_ link: DeepLink) {
        switch link {
        case .openPreset(let id):
            guard let preset = library.preset(id: id) else {
                errorHandler.showToast(String(localized: "That preset is no longer available"))
                return
            }
            applyPreset(preset)

        case .openBookmark(let id):
            guard let bookmark = library.bookmark(id: id), bookmark.url != nil else {
                errorHandler.showToast(String(localized: "That bookmark is no longer available"))
                return
            }
            if waffleState.selectedCell == nil {
                waffleState.makeInitialItem()
            }
            waffleState.loadInSelectedCell(bookmark.urlString)

        case .setGrid(let rows, let cols):
            setGridSize(rows: rows, cols: cols)

        case .openURL(let url):
            if waffleState.selectedCell == nil {
                waffleState.makeInitialItem()
            }
            waffleState.loadInSelectedCell(url.absoluteString)
        }
    }
}
