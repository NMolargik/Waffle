//
//  WaffleCell.swift
//  WaffleFeatureGrid
//
//  A single web slot's state in the grid, wrapping a live `WebPage`. WebKit-coupled by
//  nature, so it lives in the grid feature — never in Core. A `WebPage` crashes WebKit
//  when hosted by two `WebView`s at once; the one-primary-window rule exists for this.
//

import SwiftUI
import WaffleCore
import WebKit

@Observable
public final class WaffleCell: Identifiable, Hashable, Codable {
    public let id: UUID
    public let page: WebPage
    /// Holds the content rule lists and the blocked-item counter script for this cell.
    let userContentController = WKUserContentController()
    /// Per-cell content-blocking override; `.followGlobal` defers to Settings and site exceptions.
    public var contentBlockingMode: ContentBlockingMode = .followGlobal
    /// Items blocked on the current page (approximate: failed subresource loads the page observed).
    public internal(set) var blockedCount = 0
    /// Set by `GridModel`; applies the blocking policy before each load.
    @ObservationIgnored weak var blocker: ContentBlockingController?
    @ObservationIgnored var hasRuleListsInstalled = false
    /// A load requested while the rule lists were still compiling; run once they are ready.
    @ObservationIgnored var pendingLoad: String?
    public var address: String = ""
    /// Auto-refresh cadence; `GridModel` owns the timer that honors it.
    public var refreshInterval: RefreshInterval = .off

    /// Whether the web page is currently loading
    public var isLoading: Bool {
        page.isLoading
    }

    /// Estimated loading progress (0.0 to 1.0)
    public var loadingProgress: Double {
        page.estimatedProgress
    }

    /// The back/forward list changes after the navigation has already been reported, so a
    /// view reading only the list showed the state from one navigation ago. Also reading the
    /// page's URL and loading flag makes any view that asks re-evaluate when a navigation
    /// commits and again when it finishes, by which time the list is current.
    public var canGoBack: Bool {
        _ = page.url
        _ = page.isLoading
        return page.backForwardList.backList.last != nil
    }

    public var canGoForward: Bool {
        _ = page.url
        _ = page.isLoading
        return page.backForwardList.forwardList.first != nil
    }

    // MARK: Initializer

    public init(id: UUID = UUID(), url: URL? = nil) {
        self.id = id
        self.page = Self.makePage(controller: userContentController)
        if let url { address = url.absoluteString }
    }

    private static func makePage(controller: WKUserContentController) -> WebPage {
        controller.addUserScript(ContentBlockingController.counterScript)
        var configuration = WebPage.Configuration()
        configuration.userContentController = controller
        return WebPage(configuration: configuration)
    }

    public func loadURL(urlString: String) {
        self.address = urlString
        if let blocker, blocker.prepareForLoad(self, address: urlString) == .deferUntilReady {
            pendingLoad = urlString
            return
        }
        pendingLoad = nil
        self.page.load(URL(string: urlString))
    }

    /// Re-reads the page's blocked-item counter (cheap; no-op when blocking is inactive).
    public func refreshBlockedCount() async {
        guard hasRuleListsInstalled, !address.isEmpty else {
            if blockedCount != 0 { blockedCount = 0 }
            return
        }
        let value = try? await page.callJavaScript(
            "return window.__waffleBlocked ? window.__waffleBlocked.size : 0",
            contentWorld: ContentBlockingController.world
        )
        let count = (value as? Int) ?? 0
        if count != blockedCount { blockedCount = count }
    }

    public func reloadCell() {
        self.page.reload()
    }

    // MARK: History Navigation

    public func goBack() {
        guard let item = page.backForwardList.backList.last else { return }
        page.load(item)
    }

    public func goForward() {
        guard let item = page.backForwardList.forwardList.first else { return }
        page.load(item)
    }

    // MARK: - Codable Conformance

    private enum CodingKeys: String, CodingKey {
        case id
        case address
        case refreshInterval
        case contentBlockingMode
    }

    public required init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.page = Self.makePage(controller: userContentController)
        self.address = try container.decode(String.self, forKey: .address)
        self.refreshInterval = RefreshInterval(persisted: try container.decodeIfPresent(Int.self, forKey: .refreshInterval) ?? 0)
        self.contentBlockingMode = ContentBlockingMode(persisted: try container.decodeIfPresent(Int.self, forKey: .contentBlockingMode) ?? 0)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(address, forKey: .address)
        try container.encode(refreshInterval.rawValue, forKey: .refreshInterval)
        try container.encode(contentBlockingMode.rawValue, forKey: .contentBlockingMode)
    }

    // MARK: Hashable Conformance

    public static func == (lhs: WaffleCell, rhs: WaffleCell) -> Bool { lhs.id == rhs.id }
    public func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
