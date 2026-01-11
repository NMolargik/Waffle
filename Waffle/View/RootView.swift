//
//  RootView.swift
//  Waffle
//
//  Created by Nick Molargik on 9/2/25.
//

import SwiftUI

struct RootView: View {
    @Environment(\.openWindow) private var openWindow
    @Environment(WaffleCoordinator.self) private var coordinator
    
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = false

    var body: some View {
        Group {
            if hasCompletedOnboarding {
                MainView()
            } else {
                OnboardingView()
            }
        }
    }
}

#Preview {
    RootView()
}
