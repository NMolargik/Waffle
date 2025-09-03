//
//  SearchProvider.swift
//  Waffle
//
//  Created by Nick Molargik on 9/3/25.
//

import Foundation

/// Supported web search providers for constructing search query URLs.
///
/// The enum is `RawRepresentable` by `String` so it can be persisted easily
/// (e.g., in UserDefaults) and surfaced in UI pickers. It also provides a
/// human-friendly display name and a method to build a search URL for a query.
enum SearchProvider: String, CaseIterable, Codable {
    /// Google Search.
    case google
    /// DuckDuckGo Search.
    case duckduckgo

    /// A user-facing, localized display name for the provider.
    var displayName: String {
        switch self {
        case .google: return "Google"
        case .duckduckgo: return "DuckDuckGo"
        }
    }

    /// Constructs a full search URL string for the given query using this provider.
    /// - Parameter query: The raw query text entered by the user.
    /// - Returns: A URL string that performs the search with the provider.
    func searchURL(for query: String) -> String {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        switch self {
        case .google:
            return "https://www.google.com/search?q=\(encoded)"
        case .duckduckgo:
            return "https://duckduckgo.com/?q=\(encoded)"
        }
    }
}
