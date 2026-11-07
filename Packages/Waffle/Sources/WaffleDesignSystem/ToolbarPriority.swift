//
//  ToolbarPriority.swift
//  WaffleDesignSystem
//
//  Availability shim for iOS 27's toolbar `visibilityPriority`, so the app can deploy to
//  iOS 26. On 26 the system's default overflow behavior applies.
//

#if os(iOS)
import SwiftUI

public enum WaffleToolbarPriority: Sendable {
    case high, low, lowest
}

extension ToolbarContent {
    @ToolbarContentBuilder
    public func wafflePriority(_ priority: WaffleToolbarPriority) -> some ToolbarContent {
        if #available(iOS 27.0, *) {
            switch priority {
            case .high: self.visibilityPriority(.high)
            case .low: self.visibilityPriority(.low)
            case .lowest: self.visibilityPriority(ToolbarItemVisibilityPriority(lowerThan: .low))
            }
        } else {
            self
        }
    }
}
#endif
