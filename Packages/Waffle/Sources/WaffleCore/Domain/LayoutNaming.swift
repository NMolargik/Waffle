//
//  LayoutNaming.swift
//  WaffleCore
//
//  Names and summaries for layouts saved on iPhone and iPhone Duo. A layout is named from
//  the sites in its panes ("Wikipedia + Apple") instead of a timestamp, and its card lists
//  those sites. (iPad presets keep their own naming.)
//

import Foundation

nonisolated public enum LayoutNaming {
    /// The most sites a generated name lists before it stops ("A + B + C + D" is the longest).
    public static let maxNamedSites = 4

    /// The host of an address without scheme, `www.`, port or path; nil for an empty address.
    public static func host(of address: String) -> String? {
        let trimmed = address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        var text = URLDisplayFormatter.compact(trimmed)
        if let end = text.firstIndex(where: { $0 == "/" || $0 == "?" || $0 == "#" || $0 == ":" }) {
            text = String(text[..<end])
        }
        return text.isEmpty ? nil : text.lowercased()
    }

    /// "en.wikipedia.org" becomes "Wikipedia"; "bbc.co.uk" becomes "Bbc".
    public static func siteName(forAddress address: String) -> String? {
        guard let host = host(of: address) else { return nil }
        let registrable = URLDisplayFormatter.registrableDomain(of: host)
        guard let label = registrable.split(separator: ".").first.map(String.init), !label.isEmpty else { return nil }
        return label.prefix(1).uppercased() + label.dropFirst()
    }

    /// Registrable domains of a layout's panes, in order, without repeats ("wikipedia.org, apple.com").
    public static func hostSummary(urls: [String], paneCount: Int) -> String {
        let panes = paneCount > 0 ? Array(urls.prefix(paneCount)) : urls
        var seen: [String] = []
        for address in panes {
            guard let host = host(of: address) else { continue }
            let domain = URLDisplayFormatter.registrableDomain(of: host)
            if !seen.contains(domain) { seen.append(domain) }
        }
        return seen.joined(separator: ", ")
    }

    /// "Wikipedia + Apple" for the open panes' addresses, or nil when no pane has a page.
    public static func siteTitle(forAddresses addresses: [String]) -> String? {
        var names: [String] = []
        for address in addresses {
            guard let name = siteName(forAddress: address), !names.contains(name) else { continue }
            names.append(name)
            if names.count == maxNamedSites { break }
        }
        return names.isEmpty ? nil : names.joined(separator: " + ")
    }

    /// Makes `base` unique among `existing` by numbering repeats: "Wikipedia + Apple 2".
    public static func uniqued(_ base: String, existing: [String]) -> String {
        guard existing.contains(base) else { return base }
        var number = 2
        while existing.contains("\(base) \(number)") { number += 1 }
        return "\(base) \(number)"
    }

    /// The default name for a new layout: its sites, numbered if taken; nil when no pane has a
    /// page yet (the caller then falls back to a dated name).
    public static func suggestedName(addresses: [String], existingNames: [String]) -> String? {
        guard let title = siteTitle(forAddresses: addresses) else { return nil }
        return uniqued(title, existing: existingNames)
    }
}
