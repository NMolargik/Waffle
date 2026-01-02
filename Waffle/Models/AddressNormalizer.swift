//
//  AddressNormalizer.swift
//  Waffle
//
//  Created by Nick Molargik on 9/3/25.
//

import Foundation

/// Normalizes user input from the address bar into a valid URL string.
enum AddressNormalizer {
    /// Converts user input into a properly formatted URL string.
    ///
    /// The function applies the following rules:
    /// 1. If the input already has http:// or https://, return as-is
    /// 2. If the input looks like a domain (contains "." with no spaces, or starts with "www."),
    ///    prepend https://
    /// 3. Otherwise, treat as a search query and use the provided search provider
    ///
    /// - Parameters:
    ///   - input: Raw user input from the address bar
    ///   - provider: The search provider to use for search queries
    /// - Returns: A valid URL string
    static func normalize(_ input: String, using provider: SearchProvider) -> String {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return provider.searchURL(for: "") }

        if trimmed.lowercased().hasPrefix("http://") || trimmed.lowercased().hasPrefix("https://") {
            return trimmed
        }

        let hasSpaces = trimmed.contains(where: { $0.isWhitespace })
        let looksLikeDomain = trimmed.contains(".") && !hasSpaces
        let startsWithWWW = trimmed.lowercased().hasPrefix("www.")

        if looksLikeDomain || startsWithWWW {
            return "https://\(trimmed)"
        }

        return provider.searchURL(for: trimmed)
    }
}
