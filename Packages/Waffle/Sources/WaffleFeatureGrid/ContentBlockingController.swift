//
//  ContentBlockingController.swift
//  WaffleFeatureGrid
//
//  Per-cell content blocking. Compiles the bundled, pre-converted filter lists
//  (EasyList, EasyPrivacy, Easylist Cookie List — see Resources/ContentBlocking/README.md)
//  with `WKContentRuleListStore` once, then installs them on or removes them from each
//  cell's `WKUserContentController` according to `ContentBlockingPolicy`. Free feature —
//  not gated by Syrup.
//

import Foundation
import os
import WaffleCore
import WebKit

@Observable
@MainActor
public final class ContentBlockingController {
    public enum Phase: Equatable, Sendable {
        case idle, compiling, ready, failed
    }

    public enum LoadDecision: Sendable {
        case proceed, deferUntilReady
    }

    public static let disabledKey = "contentBlockingDisabled"
    public static let exceptionsKey = "contentBlockingExceptions"
    static let identifierPrefix = "waffle-"

    /// Isolated world for the counter script, so page scripts can't see or spoof it.
    static let world = WKContentWorld.world(name: "waffle-content-blocking")

    /// Records the URL of every subresource whose load failed — which is how a content
    /// rule list's `block` action surfaces to the page. Reset naturally per document.
    static let counterScript = WKUserScript(
        source: """
        (function () {
          if (window.__waffleBlocked) return;
          var seen = new Set();
          window.__waffleBlocked = seen;
          window.addEventListener('error', function (e) {
            var t = e.target;
            if (t && t !== window && (t.src || t.href)) { seen.add(t.src || t.href); }
          }, true);
        })();
        """,
        injectionTime: .atDocumentStart,
        forMainFrameOnly: true,
        in: world
    )

    public var isGloballyEnabled: Bool {
        didSet {
            guard oldValue != isGloballyEnabled else { return }
            defaults.set(!isGloballyEnabled, forKey: Self.disabledKey)
            reapplyToAllCells()
        }
    }

    /// Sites (hosts) where blocking is off while a cell follows the global setting.
    public private(set) var exceptionHosts: [String]

    public private(set) var phase: Phase = .idle

    /// The lists in use, for the Settings attribution row.
    public private(set) var listTitles: [String] = []

    /// Supplied by `GridModel`: every live cell.
    @ObservationIgnored var cells: () -> [WaffleCell] = { [] }

    @ObservationIgnored private let defaults: any KeyValueStoring
    @ObservationIgnored private var ruleLists: [WKContentRuleList] = []

    /// - Parameter compilesRules: false disables the engine entirely (host tests, previews).
    public init(defaults: any KeyValueStoring = UserDefaults.standard, compilesRules: Bool = true) {
        self.defaults = defaults
        if !compilesRules { phase = .failed }
        // Stored inverted so a missing key means "on" (the default).
        isGloballyEnabled = !defaults.bool(forKey: Self.disabledKey)
        let saved = defaults.data(forKey: Self.exceptionsKey)
            .flatMap { try? JSONDecoder().decode([String].self, from: $0) } ?? []
        exceptionHosts = Array(Set(saved)).sorted()
    }

    // MARK: - Exceptions

    public func addException(for address: String) {
        guard let host = ContentBlockingPolicy.normalizedHost(from: address),
              !exceptionHosts.contains(host) else { return }
        exceptionHosts = (exceptionHosts + [host]).sorted()
        persistExceptions()
        reapplyToAllCells()
    }

    public func removeException(host: String) {
        guard exceptionHosts.contains(host) else { return }
        exceptionHosts.removeAll { $0 == host }
        persistExceptions()
        reapplyToAllCells()
    }

    public func hasException(for address: String) -> Bool {
        guard let host = ContentBlockingPolicy.normalizedHost(from: address) else { return false }
        return ContentBlockingPolicy.isException(host: host, in: Set(exceptionHosts))
    }

    private func persistExceptions() {
        if let data = try? JSONEncoder().encode(exceptionHosts) {
            defaults.set(data, forKey: Self.exceptionsKey)
        }
    }

    // MARK: - Policy

    public func isActive(for cell: WaffleCell, address: String? = nil) -> Bool {
        ContentBlockingPolicy.isActive(
            globalEnabled: isGloballyEnabled,
            mode: cell.contentBlockingMode,
            address: address ?? cell.address,
            exceptions: Set(exceptionHosts)
        )
    }

    /// Installs/removes the rule lists on `cell` to match the policy for `address`.
    /// - Returns: true when the installed state changed.
    @discardableResult
    func apply(to cell: WaffleCell, address: String? = nil) -> Bool {
        let wantsLists = phase == .ready && isActive(for: cell, address: address)
        guard wantsLists != cell.hasRuleListsInstalled else { return false }
        if wantsLists {
            for list in ruleLists { cell.userContentController.add(list) }
        } else {
            for list in ruleLists { cell.userContentController.remove(list) }
        }
        cell.hasRuleListsInstalled = wantsLists
        if !wantsLists { cell.blockedCount = 0 }
        return true
    }

    /// Called by a cell right before it loads `address`.
    func prepareForLoad(_ cell: WaffleCell, address: String) -> LoadDecision {
        if phase == .idle { start() }
        if phase == .compiling, isActive(for: cell, address: address) { return .deferUntilReady }
        apply(to: cell, address: address)
        return .proceed
    }

    /// Re-evaluates a cell after its page navigated or its mode changed; reloads it when
    /// the blocking state flipped so the new state takes effect immediately.
    public func refresh(_ cell: WaffleCell) {
        if apply(to: cell), !cell.address.isEmpty {
            cell.reloadCell()
        }
    }

    private func reapplyToAllCells() {
        for cell in cells() { refresh(cell) }
    }

    // MARK: - Compilation

    /// Starts loading the bundled rule lists in the background (idempotent). Cells that
    /// need blocking hold their first load until this finishes.
    public func start() {
        guard phase == .idle else { return }
        phase = .compiling
        Task { await load() }
    }

    /// Loads (compiling on first run or after a list update) the bundled rule lists.
    private func load() async {
        let log = Log.grid
        do {
            let manifest = try await Self.loadManifest()
            guard let store = WKContentRuleListStore.default() else { throw CocoaError(.fileNoSuchFile) }
            var lists: [WKContentRuleList] = []
            var wanted = Set<String>()
            for entry in manifest.lists {
                let identifier = "\(Self.identifierPrefix)\(entry.id)-\(entry.version)"
                wanted.insert(identifier)
                if let existing = try? await store.contentRuleList(forIdentifier: identifier) {
                    lists.append(existing)
                    continue
                }
                let json = try await Self.loadRuleJSON(id: entry.id)
                let start = Date()
                guard let compiled = try await store.compileContentRuleList(forIdentifier: identifier, encodedContentRuleList: json) else {
                    throw CocoaError(.fileReadCorruptFile)
                }
                log.info("Compiled \(entry.id, privacy: .public) in \(Date().timeIntervalSince(start), format: .fixed(precision: 1))s")
                lists.append(compiled)
            }
            // Drop lists from older versions so updates don't accumulate on disk.
            for stale in await store.availableIdentifiers() ?? [] where stale.hasPrefix(Self.identifierPrefix) && !wanted.contains(stale) {
                try? await store.removeContentRuleList(forIdentifier: stale)
            }
            ruleLists = lists
            listTitles = manifest.lists.map(\.title)
            phase = .ready
            for cell in cells() {
                apply(to: cell)
                if let pending = cell.pendingLoad { cell.loadURL(urlString: pending) }
                else if cell.hasRuleListsInstalled, !cell.address.isEmpty { cell.reloadCell() }
            }
        } catch {
            log.error("Content blocker unavailable: \(error.localizedDescription, privacy: .public)")
            phase = .failed
            for cell in cells() {
                if let pending = cell.pendingLoad { cell.loadURL(urlString: pending) }
            }
        }
    }

    nonisolated struct Manifest: Decodable, Sendable {
        nonisolated struct Entry: Decodable, Sendable { let id: String; let title: String; let version: String }
        let lists: [Entry]
    }

    nonisolated static func resourceURL(_ name: String, ext: String) -> URL? {
        Bundle.module.url(forResource: name, withExtension: ext, subdirectory: "ContentBlocking")
            ?? Bundle.module.url(forResource: name, withExtension: ext, subdirectory: "Resources/ContentBlocking")
    }

    nonisolated static func loadManifest() async throws -> Manifest {
        guard let url = resourceURL("manifest", ext: "json") else { throw CocoaError(.fileNoSuchFile) }
        return try JSONDecoder().decode(Manifest.self, from: Data(contentsOf: url))
    }

    /// Reads and inflates a bundled list off the main actor.
    nonisolated static func loadRuleJSON(id: String) async throws -> String {
        try await Task.detached(priority: .utility) {
            guard let url = resourceURL(id, ext: "json.zlib") else { throw CocoaError(.fileNoSuchFile) }
            let inflated = try (Data(contentsOf: url) as NSData).decompressed(using: .zlib) as Data
            guard let json = String(data: inflated, encoding: .utf8) else { throw CocoaError(.fileReadCorruptFile) }
            return json
        }.value
    }
}
