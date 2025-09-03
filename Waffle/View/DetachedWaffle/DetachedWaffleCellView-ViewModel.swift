//
//  DetachedWaffleCellView-ViewModel.swift
//  Waffle
//
//  Created by Nick Molargik on 9/3/25.
//

import Foundation

extension DetachedWaffleCellView {
    @Observable
    class ViewModel {
        var addressBarString: String = ""

        func normalizedInput(_ input: String, using provider: SearchProvider) -> String {
            let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.isEmpty == false else { return provider.searchURL(for: "") }
            
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
}
