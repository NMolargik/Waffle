//
//  DeepLinkTests.swift
//  WaffleTests
//

import Foundation
import Testing
@testable import Waffle

@Suite("DeepLink")
struct DeepLinkTests {
    @Test func parsesPresetLink() throws {
        let id = UUID()
        let url = try #require(URL(string: "waffle://preset/\(id.uuidString)"))
        #expect(DeepLink(url: url) == .openPreset(id))
    }

    @Test func parsesBookmarkLink() throws {
        let id = UUID()
        let url = try #require(URL(string: "waffle://bookmark/\(id.uuidString)"))
        #expect(DeepLink(url: url) == .openBookmark(id))
    }

    @Test(arguments: [
        ("waffle://grid/2x3", 2, 3),
        ("waffle://grid/1x1", 1, 1),
        ("waffle://grid/4X4", 4, 4)
    ])
    func parsesGridLink(raw: String, rows: Int, cols: Int) throws {
        let url = try #require(URL(string: raw))
        #expect(DeepLink(url: url) == .setGrid(rows: rows, cols: cols))
    }

    @Test func parsesOpenLink() throws {
        let target = "https://apple.com/ipad"
        var components = URLComponents()
        components.scheme = "waffle"
        components.host = "open"
        components.queryItems = [URLQueryItem(name: "url", value: target)]
        let url = try #require(components.url)
        #expect(DeepLink(url: url) == .openURL(URL(string: target)!))
    }

    @Test(arguments: [
        "waffle://preset/not-a-uuid",
        "waffle://grid/0x2",
        "waffle://grid/abc",
        "waffle://unknown/thing",
        "https://apple.com",
        "waffle://open?url=javascript:alert(1)",
        "waffle://open?url=file:///etc/passwd"
    ])
    func rejectsInvalidLinks(raw: String) throws {
        let url = try #require(URL(string: raw))
        #expect(DeepLink(url: url) == nil)
    }

    @Test func caseInsensitiveScheme() throws {
        let id = UUID()
        let url = try #require(URL(string: "WAFFLE://preset/\(id.uuidString)"))
        #expect(DeepLink(url: url) == .openPreset(id))
    }

    @Test(arguments: [
        DeepLink.openPreset(UUID()),
        DeepLink.openBookmark(UUID()),
        DeepLink.setGrid(rows: 3, cols: 2),
        DeepLink.openURL(URL(string: "https://apple.com")!)
    ])
    func canonicalURLRoundTrips(link: DeepLink) {
        #expect(DeepLink(url: link.url) == link)
    }
}
