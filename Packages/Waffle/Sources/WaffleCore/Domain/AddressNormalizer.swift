//
//  AddressNormalizer.swift
//  WaffleCore
//
//  Normalizes user input from the address bar into a valid URL string.
//

import Foundation

nonisolated public enum AddressNormalizer {
    /// Converts user input into a properly formatted URL string.
    ///
    /// 1. Input with http:// or https:// returns as-is.
    /// 2. Input that looks like a domain ("." with no spaces, or "www." prefix)
    ///    gets https:// prepended.
    /// 3. Anything else becomes a search query on `provider`.
    public static func normalize(_ input: String, using provider: SearchProvider) -> String {
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
