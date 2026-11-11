//
//  RootView.swift
//  WaffleComposition
//

#if os(iOS)
import SwiftUI
import UIKit
import WaffleDesignSystem
import WaffleFeatureOnboarding

public struct RootView: View {
    private let session: SessionController

    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = false

    /// Whether this scene hosts the browsing UI. Every main window shares the
    /// same GridModel, and a WebPage crashes WebKit when hosted by two
    /// WebViews — so exactly one main scene may claim the grid at a time.
    @State private var isPrimaryWindow = false

    /// iPhone and iPhone Duo get the pane workspace. Debug builds can force it on an iPad
    /// simulator (`-WaffleForcePhoneUI YES`) as a stand-in for the Duo's inner display.
    public static var usesPhoneWorkspace: Bool {
        #if DEBUG
        if UserDefaults.standard.bool(forKey: "WaffleForcePhoneUI") { return true }
        #endif
        return UIDevice.current.userInterfaceIdiom == .phone
    }

    public init(session: SessionController) {
        self.session = session
    }

    public var body: some View {
        #if DEBUG
        if UserDefaults.standard.bool(forKey: "WaffleDebugRotatedCanvas") {
            // iPad simulators stay portrait under simctl: lay the UI out landscape inside a
            // rotated canvas (screenshots are then rotated back). Layout checks only.
            GeometryReader { proxy in
                content
                    .frame(width: proxy.size.height, height: proxy.size.width)
                    .rotationEffect(.degrees(-90))
                    .frame(width: proxy.size.width, height: proxy.size.height)
            }
        } else {
            content
        }
        #else
        content
        #endif
    }

    private var content: some View {
        Group {
            if !isPrimaryWindow {
                ExtraWindowView()
            } else if hasCompletedOnboarding {
                if Self.usesPhoneWorkspace {
                    // iPhone and iPhone Duo get the pane workspace; iPad keeps the grid.
                    PhoneMainView(session: session)
                } else {
                    MainView(session: session)
                }
            } else {
                if Self.usesPhoneWorkspace {
                    // The user has not used the app yet: no paywall after the tour on a phone.
                    OnboardingView(
                        variant: PhoneMainView.isFoldableDevice ? .iPhoneDuo : .iPhone,
                        onFinished: {}
                    )
                } else {
                    OnboardingView(onFinished: { session.presentSyrupSheet = true })
                }
            }
        }
        .onAppear {
            claimPrimaryIfAvailable()
            #if DEBUG
            // Simulators can't rotate from the command line: `-WaffleDebugOrientation landscape`.
            if UserDefaults.standard.string(forKey: "WaffleDebugOrientation") == "landscape" {
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(800))
                    for case let scene as UIWindowScene in UIApplication.shared.connectedScenes {
                        scene.requestGeometryUpdate(.iOS(interfaceOrientations: .landscapeRight))
                    }
                }
            }
            #endif
        }
        .onDisappear { releasePrimary() }
        .onChange(of: session.mainWindowCount) { _, newCount in
            // Promote this window when the primary one closes.
            if newCount == 0 {
                claimPrimaryIfAvailable()
            }
        }
    }

    private func claimPrimaryIfAvailable() {
        guard !isPrimaryWindow, session.mainWindowCount == 0 else { return }
        session.mainWindowCount += 1
        isPrimaryWindow = true
    }

    private func releasePrimary() {
        guard isPrimaryWindow else { return }
        session.mainWindowCount -= 1
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
#endif
