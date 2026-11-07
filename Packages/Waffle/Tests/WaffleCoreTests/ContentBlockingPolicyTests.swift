import Foundation
import Testing
@testable import WaffleCore

@Suite("ContentBlockingPolicy")
struct ContentBlockingPolicyTests {
    @Test func normalizesHosts() {
        #expect(ContentBlockingPolicy.normalizedHost(from: "https://www.Example.com/a?b=1") == "example.com")
        #expect(ContentBlockingPolicy.normalizedHost(from: "news.example.com") == "news.example.com")
        #expect(ContentBlockingPolicy.normalizedHost(from: "") == nil)
        #expect(ContentBlockingPolicy.normalizedHost(from: "about:blank") == nil)
    }

    @Test func exceptionMatchesSubdomains() {
        let ex: Set<String> = ["example.com"]
        #expect(ContentBlockingPolicy.isException(host: "example.com", in: ex))
        #expect(ContentBlockingPolicy.isException(host: "m.news.example.com", in: ex))
        #expect(!ContentBlockingPolicy.isException(host: "notexample.com", in: ex))
        #expect(!ContentBlockingPolicy.isException(host: "example.org", in: ex))
    }

    @Test func perCellOverrideBeatsGlobalAndExceptions() {
        let ex: Set<String> = ["example.com"]
        let url = "https://example.com/x"
        #expect(ContentBlockingPolicy.isActive(globalEnabled: false, mode: .on, address: url, exceptions: ex))
        #expect(ContentBlockingPolicy.isActive(globalEnabled: true, mode: .on, address: url, exceptions: ex))
        #expect(!ContentBlockingPolicy.isActive(globalEnabled: true, mode: .off, address: url, exceptions: []))
    }

    @Test func followGlobalHonorsSwitchAndExceptions() {
        let ex: Set<String> = ["example.com"]
        #expect(ContentBlockingPolicy.isActive(globalEnabled: true, mode: .followGlobal, address: "https://other.com", exceptions: ex))
        #expect(!ContentBlockingPolicy.isActive(globalEnabled: true, mode: .followGlobal, address: "https://www.example.com", exceptions: ex))
        #expect(!ContentBlockingPolicy.isActive(globalEnabled: false, mode: .followGlobal, address: "https://other.com", exceptions: ex))
    }

    @Test func modesDecodeLeniently() {
        #expect(ContentBlockingMode.modes(from: [1, 2, 9], count: 4) == [.on, .off, .followGlobal, .followGlobal])
    }

    @Test func oldSnapshotsDecodeWithoutModes() throws {
        let json = #"{"rows":1,"cols":1,"urls":["https://a.com"]}"#.data(using: .utf8)!
        let snap = try JSONDecoder().decode(Snapshot.self, from: json)
        #expect(snap.contentBlockingModes.isEmpty)
    }
}
