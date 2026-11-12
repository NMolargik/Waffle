//
//  ToolbarPriority.swift
//  WaffleDesignSystem
//
//  Availability shim for iOS 27's toolbar `visibilityPriority`, so the app can deploy to
//  iOS 26. On 26 the system's default overflow behavior applies.
//
//  This is deliberately NOT a `@ToolbarContentBuilder`: an `if #available` inside a toolbar
//  builder goes through `ToolbarContentBuilder.buildLimitedAvailability`, whose opaque type
//  descriptor the Xcode 27.2 SDK does not export, so optimized (Release) device builds fail
//  to link. Plain returns under `if #available` (SE-0360) need no builder.
//

#if os(iOS)
import SwiftUI

public enum WaffleToolbarPriority: Sendable {
    case high, low, lowest
}

extension ToolbarContent {
    public func wafflePriority(_ priority: WaffleToolbarPriority) -> some ToolbarContent {
        if #available(iOS 27.0, *) {
            let systemPriority: ToolbarItemVisibilityPriority
            switch priority {
            case .high: systemPriority = .high
            case .low: systemPriority = .low
            case .lowest: systemPriority = ToolbarItemVisibilityPriority(lowerThan: .low)
            }
            return self.visibilityPriority(systemPriority)
        }
        return self
    }
}
#endif
