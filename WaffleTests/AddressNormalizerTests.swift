//
//  AddressNormalizerTests.swift
//  WaffleTests
//

import Foundation
import Testing
@testable import Waffle

@Suite("AddressNormalizer")
struct AddressNormalizerTests {
    @Test(arguments: [
        "https://apple.com",
        "http://example.org/path?q=1",
        "HTTPS://MIXED.example.com"
    ])
    func passesThroughExplicitSchemes(input: String) {
        #expect(AddressNormalizer.normalize(input, using: .google) == input)
    }

    @Test(arguments: [
        ("apple.com", "https://apple.com"),
        ("www.example.org", "https://www.example.org"),
        ("  swift.org  ", "https://swift.org"),
        ("sub.domain.co.uk/path", "https://sub.domain.co.uk/path")
    ])
    func prependsHTTPSForDomains(input: String, expected: String) {
        #expect(AddressNormalizer.normalize(input, using: .google) == expected)
    }

    @Test func treatsPlainWordsAsSearch() {
        let result = AddressNormalizer.normalize("waffle recipes", using: .google)
        #expect(result.hasPrefix("https://www.google.com/search?q="))
        #expect(result.contains("waffle"))
    }

    @Test func usesSelectedProviderForSearch() {
        let result = AddressNormalizer.normalize("waffle recipes", using: .duckduckgo)
        #expect(result.hasPrefix("https://duckduckgo.com/?q="))
    }

    @Test func emptyInputFallsBackToEmptySearch() {
        let result = AddressNormalizer.normalize("   ", using: .google)
        #expect(result == SearchProvider.google.searchURL(for: ""))
    }

    @Test func sentenceWithDotIsStillSearch() {
        // "weather today. tomorrow" has a dot but also spaces — must be a search.
        let result = AddressNormalizer.normalize("weather today. tomorrow", using: .google)
        #expect(result.hasPrefix("https://www.google.com/search?q="))
    }
}

@Suite("SearchProvider")
struct SearchProviderTests {
    @Test func encodesQueries() {
        let url = SearchProvider.google.searchURL(for: "swift 6 concurrency")
        #expect(!url.contains(" "))
    }

    @Test(arguments: SearchProvider.allCases)
    func everyProviderProducesHTTPSURL(provider: SearchProvider) {
        let url = provider.searchURL(for: "test")
        #expect(url.hasPrefix("https://"))
        #expect(URL(string: url) != nil)
    }
}

@Suite("URLDisplayFormatter")
struct URLDisplayFormatterTests {
    @Test(arguments: [
        ("https://www.apple.com", "apple.com"),
        ("http://example.org", "example.org"),
        ("https://github.com/a/very/long/path/indeed", "github.com"),
        ("https://swift.org/blog", "swift.org/blog"),
        ("", "")
    ])
    func compactsURLs(input: String, expected: String) {
        #expect(URLDisplayFormatter.compact(input) == expected)
    }
}
