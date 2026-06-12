//
//  AppConfiguration.swift
//  Waffle
//
//  Created by Nick Molargik on 9/3/25.
//

import Foundation

/// Centralized configuration for app-wide constants and limits.
nonisolated enum AppConfiguration {
    // MARK: - Grid Limits

    /// Maximum rows allowed for free users
    static let maxFreeRows = 2

    /// Maximum columns allowed for free users
    static let maxFreeCols = 2

    /// Maximum rows allowed for Syrup users
    static let maxPremiumRows = 4

    /// Maximum columns allowed for Syrup users
    static let maxPremiumCols = 4

    // MARK: - Persistence

    /// Debounce interval for persisting grid state (in seconds)
    static let persistenceDebounceInterval: TimeInterval = 0.5

    // MARK: - UI

    /// Minimum width for address bar. Kept small: the idle bar shows only the
    /// compact host name, so it stays legible even when squeezed.
    static let addressBarMinWidth: CGFloat = 120

    /// Maximum width for address bar
    static let addressBarMaxWidth: CGFloat = 760

    /// Height for custom toolbar controls (reload, address bar), matching
    /// the system's glass bar buttons so the toolbar reads as one row.
    static let barControlHeight: CGFloat = 44

    /// Width for the toolbar address bar: fill the hosting window's width
    /// minus the space the surrounding toolbar controls need, clamped so the
    /// bar never collapses past legibility nor balloons on huge displays.
    /// (The toolbar proposes a compressed size to custom items, so the bar
    /// must be sized explicitly from the measured window width.)
    static func addressBarWidth(forWindowWidth windowWidth: CGFloat, reservedForControls reserved: CGFloat) -> CGFloat {
        min(max(windowWidth - reserved, addressBarMinWidth), addressBarMaxWidth)
    }

    // MARK: - URLs

    /// Fallback URL when loading presets/snapshots with missing URLs
    static let fallbackURL = "https://apple.com"
}
