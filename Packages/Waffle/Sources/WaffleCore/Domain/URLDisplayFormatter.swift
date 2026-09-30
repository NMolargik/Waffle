//
//  URLDisplayFormatter.swift
//  WaffleCore
//
//  Shortens URL strings for compact display in cells and lists.
//

import Foundation

nonisolated public enum URLDisplayFormatter {
    /// Strips the scheme and `www.` prefix, and drops long paths so the
    /// domain stays readable in tight spaces.
    public static func compact(_ urlString: String) -> String {
        var url = urlString
        if url.hasPrefix("https://") { url = String(url.dropFirst(8)) }
        else if url.hasPrefix("http://") { url = String(url.dropFirst(7)) }
        if url.hasPrefix("www.") { url = String(url.dropFirst(4)) }
        if let slashIndex = url.firstIndex(of: "/") {
            let domain = String(url[..<slashIndex])
            let path = String(url[slashIndex...])
            if path.count > 10 { return domain }
        }
        return url
    }
}
