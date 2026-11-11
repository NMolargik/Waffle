//
//  SyrupPitch.swift
//  WaffleCore
//
//  What the Syrup sheet sells on iPhone and iPhone Duo, in what order. The thing the user
//  just tried to do leads. (The iPad sheet keeps its own list.)
//

import Foundation

/// What the user was doing when the paywall appeared.
nonisolated public enum SyrupTrigger: Equatable, Sendable {
    case general, thirdPane, secondLayout, deskMode
}

nonisolated public enum SyrupFeature: CaseIterable, Equatable, Sendable {
    case morePanes, unlimitedLayouts, deskMode
}

nonisolated public struct SyrupPitch: Equatable, Sendable {
    public var trigger: SyrupTrigger
    /// On the Duo's inner display panes three and four work right now; on a regular
    /// iPhone (or the Duo's outer display) they apply on iPhone Duo and iPad only.
    public var isInnerDisplay: Bool

    public init(trigger: SyrupTrigger, isInnerDisplay: Bool) {
        self.trigger = trigger
        self.isInnerDisplay = isInnerDisplay
    }

    /// The feature the trigger is about, if any.
    public var leadFeature: SyrupFeature? {
        switch trigger {
        case .general: nil
        case .thirdPane: .morePanes
        case .secondLayout: .unlimitedLayouts
        case .deskMode: .deskMode
        }
    }

    /// Every feature, the trigger's first.
    public var features: [SyrupFeature] {
        guard let lead = leadFeature else { return SyrupFeature.allCases }
        return [lead] + SyrupFeature.allCases.filter { $0 != lead }
    }
}
