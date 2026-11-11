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

/// Which display the paywall appears on; what Syrup unlocks there differs.
nonisolated public enum SyrupDevice: Equatable, Sendable {
    /// A regular iPhone: Syrup unlocks unlimited saved layouts. Panes three and four and
    /// Desk Mode belong to the Duo's inner display and the iPad.
    case iPhone
    /// The iPhone Duo's outer display: layouts now, and panes three and four plus Desk Mode
    /// once the phone is unfolded.
    case iPhoneDuoOuter
    /// The iPhone Duo's inner display: everything works on this display.
    case iPhoneDuoInner

    public var isFoldable: Bool { self != .iPhone }
    public var isInnerDisplay: Bool { self == .iPhoneDuoInner }
}

nonisolated public struct SyrupPitch: Equatable, Sendable {
    public var trigger: SyrupTrigger
    public var device: SyrupDevice

    public init(trigger: SyrupTrigger, device: SyrupDevice) {
        self.trigger = trigger
        self.device = device
    }

    public var isInnerDisplay: Bool { device.isInnerDisplay }

    /// The feature the trigger is about, if any.
    public var leadFeature: SyrupFeature? {
        switch trigger {
        case .general: nil
        case .thirdPane: .morePanes
        case .secondLayout: .unlimitedLayouts
        case .deskMode: .deskMode
        }
    }

    /// What Syrup unlocks on this device. Auto-refresh and content blocking are free everywhere.
    public var availableFeatures: [SyrupFeature] {
        device.isFoldable ? SyrupFeature.allCases : [.unlimitedLayouts]
    }

    /// Every feature available here, the trigger's first.
    public var features: [SyrupFeature] {
        let all = availableFeatures
        guard let lead = leadFeature, all.contains(lead) else { return all }
        return [lead] + all.filter { $0 != lead }
    }
}
