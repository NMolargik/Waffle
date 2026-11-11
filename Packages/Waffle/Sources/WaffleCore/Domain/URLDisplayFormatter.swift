//
//  URLDisplayFormatter.swift
//  WaffleCore
//
//  Shortens URL strings for compact display in cells and lists.
//

import Foundation

nonisolated public enum URLDisplayFormatter {
    /// Two-label public suffixes where the registrable domain keeps three labels.
    private static let secondLevelSuffixes: Set<String> = [
        "co.uk", "org.uk", "ac.uk", "gov.uk", "com.au", "net.au", "org.au", "co.nz", "co.jp",
        "co.in", "com.br", "com.cn", "com.mx", "co.za", "com.sg", "com.tr",
    ]

    /// Phone styling of `compact`: no trailing slash, so "weather.gov/" and "en.wikipedia.org"
    /// read the same way. (The iPad keeps `compact` as is.)
    public static func phoneDisplay(_ urlString: String) -> String {
        var text = compact(urlString)
        while text.count > 1, text.hasSuffix("/") { text.removeLast() }
        return text
    }

    /// The registrable domain of a host: "en.wikipedia.org" becomes "wikipedia.org". Hosts
    /// that are already short, or IP addresses, come back unchanged.
    public static func registrableDomain(of host: String) -> String {
        let labels = host.split(separator: ".").map(String.init)
        guard labels.count > 2 else { return host }
        if labels.allSatisfy({ $0.allSatisfy(\.isNumber) }) { return host }
        let lastTwo = labels.suffix(2).joined(separator: ".")
        let keep = secondLevelSuffixes.contains(lastTwo) ? 3 : 2
        return labels.suffix(keep).joined(separator: ".")
    }

    /// The most informative phone display that `fits`: the compact address, then its host
    /// alone, then the registrable domain; the shortest if none fit (the field truncates it).
    public static func phoneDisplay(_ urlString: String, fits: (String) -> Bool) -> String {
        let full = phoneDisplay(urlString)
        let host = full.firstIndex(of: "/").map { String(full[..<$0]) } ?? full
        let registrable = registrableDomain(of: host)
        for candidate in [full, host, registrable] where fits(candidate) { return candidate }
        return registrable
    }

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
