//
//  AutoRefreshTests.swift
//  WaffleCoreTests
//

import Foundation
import Testing
import WaffleCore

@Suite("RefreshInterval")
struct RefreshIntervalTests {
    @Test func rawValuesAreSeconds() {
        #expect(RefreshInterval.off.seconds == nil)
        #expect(RefreshInterval.thirtySeconds.seconds == 30)
        #expect(RefreshInterval.oneMinute.seconds == 60)
        #expect(RefreshInterval.fiveMinutes.seconds == 300)
        #expect(RefreshInterval.fifteenMinutes.seconds == 900)
    }

    @Test func persistedUnknownValueFallsBackToOff() {
        #expect(RefreshInterval(persisted: 45) == .off)
        #expect(RefreshInterval(persisted: 60) == .oneMinute)
    }

    @Test func intervalsPadAndTruncateToCellCount() {
        #expect(RefreshInterval.intervals(from: [30, 0, 300], count: 4) == [.thirtySeconds, .off, .fiveMinutes, .off])
        #expect(RefreshInterval.intervals(from: [30, 60, 300], count: 2) == [.thirtySeconds, .oneMinute])
        #expect(RefreshInterval.intervals(from: [], count: 2) == [.off, .off])
    }
}

@Suite("AutoRefreshScheduler")
struct AutoRefreshSchedulerTests {
    let t0 = Date(timeIntervalSinceReferenceDate: 1_000_000)

    @Test func offNeverFires() {
        var s = AutoRefreshScheduler(interval: .off, now: t0)
        #expect(!s.isEnabled)
        #expect(s.nextFireDate() == nil)
        let fired1 = s.fireIfDue(now: t0.addingTimeInterval(10_000))
        #expect(!fired1)
    }

    @Test func firesOncePerIntervalAndReanchors() {
        var s = AutoRefreshScheduler(interval: .thirtySeconds, now: t0)
        #expect(s.nextFireDate() == t0.addingTimeInterval(30))
        let fired2 = s.fireIfDue(now: t0.addingTimeInterval(29))
        #expect(!fired2)
        let fired3 = s.fireIfDue(now: t0.addingTimeInterval(30))
        #expect(fired3)
        #expect(s.anchor == t0.addingTimeInterval(30))
        #expect(s.nextFireDate() == t0.addingTimeInterval(60))
        let fired4 = s.fireIfDue(now: t0.addingTimeInterval(31))
        #expect(!fired4)
    }

    @Test func doesNotFireWhileAppInactive() {
        var s = AutoRefreshScheduler(interval: .oneMinute, now: t0)
        s.appDidResignActive()
        #expect(!s.isEnabled)
        #expect(s.nextFireDate() == nil)
        let fired5 = s.fireIfDue(now: t0.addingTimeInterval(600))
        #expect(!fired5)
    }

    @Test func becomingActiveRestartsCountdownWithoutBurst() {
        var s = AutoRefreshScheduler(interval: .oneMinute, now: t0)
        s.appDidResignActive()
        let resumed = t0.addingTimeInterval(3_600)
        s.appDidBecomeActive(now: resumed)
        let fired6 = s.fireIfDue(now: resumed)
        #expect(!fired6)
        #expect(s.nextFireDate() == resumed.addingTimeInterval(60))
    }

    @Test func changingIntervalRestartsCountdown() {
        var s = AutoRefreshScheduler(interval: .thirtySeconds, now: t0)
        let later = t0.addingTimeInterval(20)
        s.setInterval(.fiveMinutes, now: later)
        #expect(s.nextFireDate() == later.addingTimeInterval(300))
        s.setInterval(.off, now: later)
        #expect(s.nextFireDate() == nil)
    }
}

@Suite("Snapshot refresh intervals")
struct SnapshotRefreshIntervalTests {
    @Test func roundTripsIntervals() throws {
        let snapshot = Snapshot(rows: 1, cols: 2, urls: ["https://a.example", "https://b.example"], selectedIndex: 0, refreshIntervals: [30, 0])
        let data = try JSONEncoder().encode(snapshot)
        let decoded = try JSONDecoder().decode(Snapshot.self, from: data)
        #expect(decoded == snapshot)
        #expect(decoded.refreshIntervals == [30, 0])
    }

    @Test func decodesPre150SnapshotsWithoutIntervals() throws {
        let legacy = Data(#"{"rows":1,"cols":1,"urls":["https://apple.com"],"selectedIndex":0}"#.utf8)
        let decoded = try JSONDecoder().decode(Snapshot.self, from: legacy)
        #expect(decoded.refreshIntervals.isEmpty)
        #expect(decoded.urls == ["https://apple.com"])
    }
}

@Suite("PresetShare")
struct PresetShareTests {
    @Test func textHasDeepLinkThenURLs() {
        let id = UUID()
        let text = PresetShare.text(name: "Morning", id: id, rows: 1, cols: 2, urls: ["https://a.example", " ", "https://b.example"])
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        #expect(lines[0] == "Morning (1x2)")
        #expect(lines[1] == "waffle://preset/\(id.uuidString)")
        #expect(DeepLink(url: URL(string: lines[1])!) == .openPreset(id))
        #expect(lines[2] == "")
        #expect(Array(lines[3...]) == ["https://a.example", "https://b.example"])
    }

    @Test func blankNameGetsGenericTitle() {
        let text = PresetShare.text(name: "  ", id: UUID(), rows: 2, cols: 2, urls: [])
        #expect(text.hasPrefix("Waffle preset (2x2)\nwaffle://preset/"))
        #expect(!text.hasSuffix("\n"))
    }
}
