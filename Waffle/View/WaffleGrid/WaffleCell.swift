//
//  WaffleCell.swift
//  Waffle
//
//  Created by Nick Molargik on 9/2/25.
//

import SwiftUI
import WebKit

/// A single web slot's state in the grid.
@Observable
final class WaffleCell: Identifiable, Hashable, Codable {
    let id: UUID
    let page = WebPage()
    var address: String = ""
    
    var canGoBack: Bool {
        page.backForwardList.backList.last != nil
    }
    
    var canGoForward: Bool {
        page.backForwardList.forwardList.first != nil
    }
    
    // MARK: Initializer
    init(id: UUID = UUID(), url: URL? = nil) {
        self.id = id
        if let url { address = url.absoluteString }
    }
    
    func loadURL(urlString: String) {
        self.address = urlString
        self.page.load(URL(string: urlString))
    }
    
    func reloadCell() {
        self.page.reload()
    }
    
    // MARK: History Navigation
    func goBack() {
        guard let item = page.backForwardList.backList.last else { return }
        page.load(item)
    }
    
    func goForward() {
        guard let item = page.backForwardList.forwardList.first else { return }
        page.load(item)
    }
    
    // MARK: - Codable Conformance
    private enum CodingKeys: String, CodingKey {
        case id
        case address
    }
    
    required init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.address = try container.decode(String.self, forKey: .address)
    }
    
    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(address, forKey: .address)
    }
    
    // MARK: Hashable Conformance
    static func == (lhs: WaffleCell, rhs: WaffleCell) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
