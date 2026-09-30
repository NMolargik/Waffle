//
//  SearchProvider.swift
//  WaffleCore
//
//  Supported web search providers for constructing search query URLs.
//

import Foundation

/// `RawRepresentable` by `String` so it persists easily (UserDefaults) and
/// surfaces in UI pickers.
nonisolated public enum SearchProvider: String, CaseIterable, Codable, Sendable {
    case google
    case duckduckgo

    /// A user-facing display name for the provider (brand names, untranslated).
    public var displayName: String {
        switch self {
        case .google: return "Google"
        case .duckduckgo: return "DuckDuckGo"
        }
    }

    /// Constructs a full search URL string for the given query using this provider.
    public func searchURL(for query: String) -> String {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        switch self {
        case .google:
            return "https://www.google.com/search?q=\(encoded)"
        case .duckduckgo:
            return "https://duckduckgo.com/?q=\(encoded)"
        }
    }
}
