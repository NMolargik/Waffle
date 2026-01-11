//
//  WaffleCoordinator.swift
//  Waffle
//
//  Created by Nick Molargik on 9/2/25.
//

import Foundation
import SwiftUI

@Observable
@MainActor
final class WaffleCoordinator {
    var waffleState = WaffleState()
    var presentSyrupSheet = false

    // Store
    let store: StoreManager

    // Error handling
    let errorHandler = ErrorHandler()

    init(store: StoreManager) {
        self.store = store
    }

    // Entitlement proxy
    var isSyrupEnabled: Bool {
        store.isPurchased
    }

    // Permissions
    var canUseRearrange: Bool { isSyrupEnabled }
    var canUsePopout: Bool { isSyrupEnabled }
    var canUseFullscreen: Bool { isSyrupEnabled }
    var canMakePresets: Bool { isSyrupEnabled }

    // Grid limits
    var maxRows: Int { isSyrupEnabled ? AppConfiguration.maxPremiumRows : AppConfiguration.maxFreeRows }
    var maxCols: Int { isSyrupEnabled ? AppConfiguration.maxPremiumCols : AppConfiguration.maxFreeCols }

    func requestSyrup() {
        presentSyrupSheet = true
    }
}
