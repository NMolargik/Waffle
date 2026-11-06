//
//  RefreshInterval.swift
//  WaffleCore
//
//  Per-cell auto-refresh cadence. Raw value is the period in seconds (0 = off) so it
//  persists as a plain integer in snapshots and presets (CloudKit-friendly).
//

import Foundation

nonisolated public enum RefreshInterval: Int, CaseIterable, Codable, Sendable, Hashable {
    case off = 0
    case thirtySeconds = 30
    case oneMinute = 60
    case fiveMinutes = 300
    case fifteenMinutes = 900

    /// The period between reloads, or nil when auto-refresh is off.
    public var seconds: TimeInterval? {
        self == .off ? nil : TimeInterval(rawValue)
    }

    /// Lenient decode from a persisted integer: unknown values fall back to off.
    public init(persisted raw: Int) {
        self = RefreshInterval(rawValue: raw) ?? .off
    }

    /// Pads/truncates a persisted seconds list to `count` entries (row-major, missing = off).
    public static func intervals(from raw: [Int], count: Int) -> [RefreshInterval] {
        (0..<max(0, count)).map { index in
            index < raw.count ? RefreshInterval(persisted: raw[index]) : .off
        }
    }
}

/// Pure timing model behind a cell's auto-refresh timer. Owns the anchor date (the last
/// reload or the last time the app became active) and the app-active gate, so the
/// feature-side task only has to sleep until `nextFireDate()` and call `fireIfDue`.
nonisolated public struct AutoRefreshScheduler: Equatable, Sendable {
    public private(set) var interval: RefreshInterval
    public private(set) var isAppActive: Bool
    /// Reference point the next reload is measured from.
    public private(set) var anchor: Date

    public init(interval: RefreshInterval, isAppActive: Bool = true, now: Date) {
        self.interval = interval
        self.isAppActive = isAppActive
        self.anchor = now
    }

    /// True when the cell should be ticking: an interval is set and the app is active.
    public var isEnabled: Bool { interval != .off && isAppActive }

    /// When the next reload is due, or nil when disabled.
    public func nextFireDate() -> Date? {
        guard isEnabled, let seconds = interval.seconds else { return nil }
        return anchor.addingTimeInterval(seconds)
    }

    /// Changing the interval restarts the countdown from `now`.
    public mutating func setInterval(_ interval: RefreshInterval, now: Date) {
        self.interval = interval
        self.anchor = now
    }

    /// Reloads never happen in the background; returning to the foreground restarts the
    /// countdown rather than firing a burst of overdue reloads.
    public mutating func appDidBecomeActive(now: Date) {
        isAppActive = true
        anchor = now
    }

    public mutating func appDidResignActive() {
        isAppActive = false
    }

    /// Returns true (and re-anchors) when a reload is due at `now`.
    public mutating func fireIfDue(now: Date) -> Bool {
        guard let next = nextFireDate(), now >= next else { return false }
        anchor = now
        return true
    }
}
