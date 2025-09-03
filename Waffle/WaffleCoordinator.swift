//
//  WaffleCoordinator.swift
//  Waffle
//
//  Created by Nick Molargik on 9/2/25.
//

import Foundation
import SwiftUI
import Observation

@Observable
@MainActor
final class WaffleCoordinator {
    var waffleState = WaffleState()
    var presentSyrupSheet = false

    // Store
    let store: StoreManager

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
    var maxFreeRows: Int { 2 }
    var maxFreeCols: Int { 2 }

    func requestSyrup() {
        presentSyrupSheet = true
    }
}
