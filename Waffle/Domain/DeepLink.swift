//
//  DeepLink.swift
//  Waffle
//
//  Parses waffle:// URLs used by App Intents, Spotlight, and external callers.
//

import Foundation

/// A parsed `waffle://` deep link.
///
/// Supported forms:
/// - `waffle://preset/<uuid>` — apply a saved preset
/// - `waffle://bookmark/<uuid>` — load a bookmark into the selected cell
/// - `waffle://grid/<rows>x<cols>` — resize the grid
/// - `waffle://open?url=<percent-encoded url>` — load a web URL into the selected cell
nonisolated enum DeepLink: Equatable {
    case openPreset(UUID)
    case openBookmark(UUID)
    case setGrid(rows: Int, cols: Int)
    case openURL(URL)

    static let scheme = "waffle"

    init?(url: URL) {
        guard url.scheme?.lowercased() == Self.scheme else { return nil }
        guard let host = url.host()?.lowercased() else { return nil }
        let pathComponents = url.pathComponents.filter { $0 != "/" }

        switch host {
        case "preset":
            guard let raw = pathComponents.first, let id = UUID(uuidString: raw) else { return nil }
            self = .openPreset(id)
        case "bookmark":
            guard let raw = pathComponents.first, let id = UUID(uuidString: raw) else { return nil }
            self = .openBookmark(id)
        case "grid":
            guard let raw = pathComponents.first else { return nil }
            let parts = raw.lowercased().split(separator: "x")
            guard parts.count == 2,
                  let rows = Int(parts[0]), let cols = Int(parts[1]),
                  rows >= 1, cols >= 1 else { return nil }
            self = .setGrid(rows: rows, cols: cols)
        case "open":
            guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
                  let raw = components.queryItems?.first(where: { $0.name == "url" })?.value,
                  let target = URL(string: raw),
                  target.scheme == "https" || target.scheme == "http" else { return nil }
            self = .openURL(target)
        default:
            return nil
        }
    }

    /// The canonical URL for this deep link.
    var url: URL {
        var components = URLComponents()
        components.scheme = Self.scheme
        switch self {
        case .openPreset(let id):
            components.host = "preset"
            components.path = "/\(id.uuidString)"
        case .openBookmark(let id):
            components.host = "bookmark"
            components.path = "/\(id.uuidString)"
        case .setGrid(let rows, let cols):
            components.host = "grid"
            components.path = "/\(rows)x\(cols)"
        case .openURL(let target):
            components.host = "open"
            components.queryItems = [URLQueryItem(name: "url", value: target.absoluteString)]
        }
        return components.url!
    }
}
