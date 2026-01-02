//
//  AppConfiguration.swift
//  Waffle
//
//  Created by Nick Molargik on 9/3/25.
//

import Foundation

/// Centralized configuration for app-wide constants and limits.
enum AppConfiguration {
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

    /// Minimum width for address bar
    static let addressBarMinWidth: CGFloat = 200

    /// Ideal width for address bar
    static let addressBarIdealWidth: CGFloat = 400

    /// Maximum width for address bar
    static let addressBarMaxWidth: CGFloat = 600

    // MARK: - URLs

    /// Fallback URL when loading presets/snapshots with missing URLs
    static let fallbackURL = "https://apple.com"
}
