//
//  AppConfiguration.swift
//  WaffleCore
//
//  Centralized configuration for app-wide constants and limits.
//

import Foundation

nonisolated public enum AppConfiguration {
    // MARK: - Grid Limits

    /// Maximum rows allowed for free users
    public static let maxFreeRows = 2

    /// Maximum columns allowed for free users
    public static let maxFreeCols = 2

    /// Maximum rows allowed for Syrup users
    public static let maxPremiumRows = 4

    /// Maximum columns allowed for Syrup users
    public static let maxPremiumCols = 4

    // MARK: - Persistence

    /// Debounce interval for persisting grid state (in seconds)
    public static let persistenceDebounceInterval: TimeInterval = 0.5

    // MARK: - UI

    /// Minimum width for address bar. Kept small: the idle bar shows only the
    /// compact host name, so it stays legible even when squeezed.
    public static let addressBarMinWidth: CGFloat = 120

    /// Maximum width for address bar
    public static let addressBarMaxWidth: CGFloat = 760

    /// Height for custom toolbar controls (reload, address bar), matching
    /// the system's glass bar buttons so the toolbar reads as one row.
    public static let barControlHeight: CGFloat = 44

    /// Width for the toolbar address bar: fill the hosting window's width
    /// minus the space the surrounding toolbar controls need, clamped so the
    /// bar never collapses past legibility nor balloons on huge displays.
    /// (The toolbar proposes a compressed size to custom items, so the bar
    /// must be sized explicitly from the measured window width.)
    public static func addressBarWidth(forWindowWidth windowWidth: CGFloat, reservedForControls reserved: CGFloat) -> CGFloat {
        min(max(windowWidth - reserved, addressBarMinWidth), addressBarMaxWidth)
    }

    /// Points the toolbar keeps free around the address bar while it's being
    /// edited: only the bar's own horizontal insets, since every other toolbar
    /// control hides to make room.
    public static let addressBarEditingReservedWidth: CGFloat = 32

    /// Width for the address bar while editing: fills the window minus its
    /// insets. Deliberately not capped at `addressBarMaxWidth` — a long URL
    /// under edit benefits from every point of width — but never below the
    /// idle minimum.
    public static func editingAddressBarWidth(forWindowWidth windowWidth: CGFloat) -> CGFloat {
        max(windowWidth - addressBarEditingReservedWidth, addressBarMinWidth)
    }

    // MARK: - URLs

    /// Fallback URL when loading presets/snapshots with missing URLs
    public static let fallbackURL = "https://apple.com"
}
