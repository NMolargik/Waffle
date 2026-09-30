//
//  WaffleCell.swift
//  WaffleFeatureGrid
//
//  A single web slot's state in the grid, wrapping a live `WebPage`. WebKit-coupled by
//  nature, so it lives in the grid feature — never in Core. A `WebPage` crashes WebKit
//  when hosted by two `WebView`s at once; the one-primary-window rule exists for this.
//

import SwiftUI
import WebKit

@Observable
public final class WaffleCell: Identifiable, Hashable, Codable {
    public let id: UUID
    public let page = WebPage()
    public var address: String = ""

    /// Whether the web page is currently loading
    public var isLoading: Bool {
        page.isLoading
    }

    /// Estimated loading progress (0.0 to 1.0)
    public var loadingProgress: Double {
        page.estimatedProgress
    }

    public var canGoBack: Bool {
        page.backForwardList.backList.last != nil
    }

    public var canGoForward: Bool {
        page.backForwardList.forwardList.first != nil
    }

    // MARK: Initializer

    public init(id: UUID = UUID(), url: URL? = nil) {
        self.id = id
        if let url { address = url.absoluteString }
    }

    public func loadURL(urlString: String) {
        self.address = urlString
        self.page.load(URL(string: urlString))
    }

    public func reloadCell() {
        self.page.reload()
    }

    // MARK: History Navigation

    public func goBack() {
        guard let item = page.backForwardList.backList.last else { return }
        page.load(item)
    }

    public func goForward() {
        guard let item = page.backForwardList.forwardList.first else { return }
        page.load(item)
    }

    // MARK: - Codable Conformance

    private enum CodingKeys: String, CodingKey {
        case id
        case address
    }

    public required init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.address = try container.decode(String.self, forKey: .address)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(address, forKey: .address)
    }

    // MARK: Hashable Conformance

    public static func == (lhs: WaffleCell, rhs: WaffleCell) -> Bool { lhs.id == rhs.id }
    public func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
