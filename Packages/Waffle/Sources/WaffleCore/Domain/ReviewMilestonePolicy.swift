//
//  ReviewMilestonePolicy.swift
//  WaffleCore
//
//  Decides when to ask for an App Store review. Waffle asks at a value moment instead of
//  the old fifth launch: when the user saves their second preset, or the first time a
//  3x3-or-larger grid is shown — and never more than once per app version. Counters live
//  behind `KeyValueStoring` so the policy is host-testable with a fake store.
//

import Foundation

@MainActor
public struct ReviewMilestonePolicy {

    public enum Keys {
        public static let presetSaveCount = "reviewPresetSaveCount"
        public static let hasOpenedLargeGrid = "reviewHasOpenedLargeGrid"
        public static let lastPromptedVersion = "lastReviewPromptVersion"
    }

    /// The preset save (1-based) that earns a prompt.
    public static let presetSaveMilestone = 2
    /// A grid counts as "large" when both dimensions reach this.
    public static let largeGridMinimum = 3

    private let defaults: any KeyValueStoring

    public init(defaults: any KeyValueStoring = UserDefaults.standard) {
        self.defaults = defaults
    }

    public var presetSaveCount: Int { defaults.integer(forKey: Keys.presetSaveCount) }
    public var hasOpenedLargeGrid: Bool { defaults.bool(forKey: Keys.hasOpenedLargeGrid) }
    public var lastPromptedVersion: String? { defaults.string(forKey: Keys.lastPromptedVersion) }

    /// Records a saved preset. Returns true when the caller should request a review now.
    @discardableResult
    public func recordPresetSaved(appVersion: String) -> Bool {
        let count = presetSaveCount + 1
        defaults.set(count, forKey: Keys.presetSaveCount)
        guard count == Self.presetSaveMilestone else { return false }
        return claimPrompt(for: appVersion)
    }

    /// Records that a `rows`x`cols` grid was shown. Returns true the first time a large
    /// grid appears (and this version hasn't prompted yet).
    @discardableResult
    public func recordGridShown(rows: Int, cols: Int, appVersion: String) -> Bool {
        guard rows >= Self.largeGridMinimum, cols >= Self.largeGridMinimum else { return false }
        guard !hasOpenedLargeGrid else { return false }
        defaults.set(true, forKey: Keys.hasOpenedLargeGrid)
        return claimPrompt(for: appVersion)
    }

    /// Marks `appVersion` as prompted unless it already was.
    private func claimPrompt(for appVersion: String) -> Bool {
        guard lastPromptedVersion != appVersion else { return false }
        defaults.set(appVersion, forKey: Keys.lastPromptedVersion)
        return true
    }
}
