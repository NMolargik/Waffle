//
//  ContentBlockingPolicy.swift
//  WaffleCore
//
//  Pure rules for per-cell content blocking: the per-cell override, the global switch,
//  and per-site exceptions. WebKit-free so it is host-testable; the Grid feature applies
//  the verdict to a cell's `WKContentRuleList`s.
//

import Foundation

/// A cell's content-blocking override. Raw value persists in snapshots.
nonisolated public enum ContentBlockingMode: Int, CaseIterable, Codable, Sendable, Hashable {
    case followGlobal = 0
    case on = 1
    case off = 2

    /// Lenient decode from a persisted integer: unknown values follow the global setting.
    public init(persisted raw: Int) {
        self = ContentBlockingMode(rawValue: raw) ?? .followGlobal
    }

    public static func modes(from raw: [Int], count: Int) -> [ContentBlockingMode] {
        (0..<max(0, count)).map { index in
            index < raw.count ? ContentBlockingMode(persisted: raw[index]) : .followGlobal
        }
    }
}

nonisolated public enum ContentBlockingPolicy {
    /// Normalizes a URL string or bare host to a comparable host: lowercased, no `www.`.
    /// Returns nil for input with no host (about:blank, empty, garbage).
    public static func normalizedHost(from address: String) -> String? {
        let trimmed = address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        var host = URL(string: trimmed)?.host()
        if host == nil, !trimmed.contains("://"), !trimmed.contains("/") {
            host = URL(string: "https://\(trimmed)")?.host()
        }
        guard var result = host?.lowercased(), !result.isEmpty else { return nil }
        if result.hasPrefix("www.") { result.removeFirst(4) }
        return result
    }

    /// True when `host` equals an exception or is a subdomain of one.
    public static func isException(host: String, in exceptions: Set<String>) -> Bool {
        let labels = host.split(separator: ".")
        return labels.indices.contains { exceptions.contains(labels[$0...].joined(separator: ".")) }
    }

    /// Whether blocking should be active for a page. An explicit per-cell `.on`/`.off`
    /// wins over everything; `.followGlobal` uses the global switch, minus site exceptions.
    public static func isActive(
        globalEnabled: Bool,
        mode: ContentBlockingMode,
        address: String,
        exceptions: Set<String>
    ) -> Bool {
        switch mode {
        case .on: return true
        case .off: return false
        case .followGlobal:
            guard globalEnabled else { return false }
            guard let host = normalizedHost(from: address) else { return true }
            return !isException(host: host, in: exceptions)
        }
    }
}
