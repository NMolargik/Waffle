//
//  FoldableDevice.swift
//  WaffleCore
//
//  Whether this phone is an iPhone Duo, so the wording can say "unfold" instead of
//  "this iPhone fits two panes". Keyed on the hardware model identifier (the Duo's outer
//  display reports no fold geometry while closed). Needs a real Duo to confirm the
//  identifier the device reports; the simulator reports the same string.
//

import Foundation

nonisolated public enum FoldableDevice {
    /// Model identifiers of foldable iPhones (iPhone Duo: `iPhone19,4`).
    public static let modelIdentifiers: Set<String> = ["iPhone19,4"]

    public static func isFoldable(modelIdentifier: String) -> Bool {
        modelIdentifiers.contains(modelIdentifier)
    }

    /// What to tell a user who tries to add a pane past what this display holds.
    public enum LimitMessage: Equatable, Sendable {
        case unfoldToAddMore, phoneFitsTwo, displayFits(Int)
    }

    public static func limitMessage(mode: PaneMode, isFoldable: Bool) -> LimitMessage {
        switch mode {
        case .compact: isFoldable ? .unfoldToAddMore : .phoneFitsTwo
        case .inner: .displayFits(PaneLimits.deviceMax(for: .inner))
        }
    }
}
