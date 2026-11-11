//
//  AddressNormalizerTests.swift
//  WaffleCoreTests
//

import Foundation
import Testing
import WaffleCore

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

@Suite("URLDisplayFormatter phone display")
struct PhoneDisplayTests {
    @Test func dropsABareTrailingSlashOnly() {
        #expect(URLDisplayFormatter.phoneDisplay("https://www.weather.gov/") == "weather.gov")
        #expect(URLDisplayFormatter.phoneDisplay("https://en.wikipedia.org") == "en.wikipedia.org")
        #expect(URLDisplayFormatter.phoneDisplay("https://apple.com/store/") == "apple.com/store")
        // The iPad's formatter is unchanged.
        #expect(URLDisplayFormatter.compact("https://www.weather.gov/") == "weather.gov/")
    }

    @Test func registrableDomains() {
        #expect(URLDisplayFormatter.registrableDomain(of: "en.wikipedia.org") == "wikipedia.org")
        #expect(URLDisplayFormatter.registrableDomain(of: "news.bbc.co.uk") == "bbc.co.uk")
        #expect(URLDisplayFormatter.registrableDomain(of: "weather.gov") == "weather.gov")
        #expect(URLDisplayFormatter.registrableDomain(of: "192.168.0.10") == "192.168.0.10")
    }

    @Test func prefersTheRegistrableDomainOverATruncatedHost() {
        let url = "https://en.wikipedia.org/wiki/Waffle"
        #expect(URLDisplayFormatter.phoneDisplay(url) { _ in true } == "en.wikipedia.org")
        #expect(URLDisplayFormatter.phoneDisplay(url) { $0.count <= 14 } == "wikipedia.org")
        #expect(URLDisplayFormatter.phoneDisplay(url) { _ in false } == "wikipedia.org")
    }
}
