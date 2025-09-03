//
//  SettingsView-ViewModel.swift
//  Waffle
//
//  Created by Nick Molargik on 9/3/25.
//

import Foundation
import SwiftUI

extension SettingsView {
    @Observable
    class ViewModel {
        var showDeleteBookmarksConfirm = false
        var showDeletePresetsConfirm = false

        var appVersionString: String {
            let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
            let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
            return "Version \(version) (\(build))"
        }
    }
}

#Preview {
    SettingsView()
        .environment(WaffleCoordinator(store: StoreManager()))
}
