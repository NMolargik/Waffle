//
//  RootView.swift
//  Waffle
//
//  Created by Nick Molargik on 9/2/25.
//

import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(WaffleCoordinator.self) private var coordinator

    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = false

    /// Whether this scene hosts the browsing UI. Every main window shares the
    /// same WaffleState, and a WebPage crashes WebKit when hosted by two
    /// WebViews — so exactly one main scene may claim the grid at a time.
    @State private var isPrimaryWindow = false

    var body: some View {
        Group {
            if !isPrimaryWindow {
                ExtraWindowView()
            } else if hasCompletedOnboarding {
                MainView()
            } else {
                OnboardingView()
            }
        }
        .onAppear { claimPrimaryIfAvailable() }
        .onDisappear { releasePrimary() }
        .onChange(of: coordinator.mainWindowCount) { _, newCount in
            // Promote this window when the primary one closes.
            if newCount == 0 {
                claimPrimaryIfAvailable()
            }
        }
    }

    private func claimPrimaryIfAvailable() {
        guard !isPrimaryWindow, coordinator.mainWindowCount == 0 else { return }
        coordinator.mainWindowCount += 1
        isPrimaryWindow = true
    }

    private func releasePrimary() {
        guard isPrimaryWindow else { return }
        coordinator.mainWindowCount -= 1
        isPrimaryWindow = false
    }
}

/// Shown in any additional main window: the waffle grid can only render in
/// one window at a time, so extra windows get a gentle signpost instead.
private struct ExtraWindowView: View {
    @Environment(\.dismissWindow) private var dismissWindow

    var body: some View {
        VStack(spacing: 20) {
            Image("waffleImage")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 80, height: 80)
                .foregroundStyle(Color.waffleSecondary)

            VStack(spacing: 8) {
                Text("Waffle is already open")
                    .font(.title2.bold())

                Text("Your waffle grid lives in another window. Close this one to keep browsing there.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 360)
            }

            Button(String(localized: "Close Window"), systemImage: "xmark.circle.fill") {
                dismissWindow()
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.waffleTertiary)
            .accessibilityHint(Text("Closes this extra window"))
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.wafflePrimary.opacity(0.3))
    }
}

#Preview {
    RootView()
        .modelContainer(PreviewSupport.makeContainer())
        .environment(PreviewSupport.makeCoordinator())
}
