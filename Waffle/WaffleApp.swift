//
//  WaffleApp.swift
//  Waffle
//
//  Created by Nick Molargik on 8/30/25.
//

import SwiftUI
import SwiftData
import StoreKit

@main
struct WaffleApp: App {
    private let container: ModelContainer
    private let storeManager = StoreManager()
    @State private var waffleCoordinator: WaffleCoordinator

    private let appGroup = "group.com.molargiksoftware.Waffle"

    // Review prompt tracking
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("launchCount") private var launchCount: Int = 0
    @State private var didIncrementThisRun: Bool = false
    @State private var attemptedReviewThisActivation: Bool = false

    init() {
        do {
            let config = ModelConfiguration("iCloud.com.molargiksoftware.Waffle")
            container = try ModelContainer(for: Bookmark.self, Preset.self, configurations: config)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
        // Initialize coordinator with store
        _waffleCoordinator = State(initialValue: WaffleCoordinator(store: storeManager))
    }

    var body: some Scene {
        WindowGroup(id: "main") {
            RootView()
                .frame(minWidth: 820)
                .modelContainer(container)
                .environment(waffleCoordinator)
                .environment(storeManager)
                .onChange(of: scenePhase) { _, newPhase in
                    handleScenePhaseChange(newPhase)
                }
        }
        .defaultSize(width: 520, height: 520)
        .windowResizability(.contentSize)
        .handlesExternalEvents(matching: ["main"])
        .commands { }

        WindowGroup(id: "DetachedWaffleCell", for: WaffleCell.self) { $waffleCell in
            if let waffleCell {
                DetachedWaffleCellView(waffleCell: waffleCell)
                    .environment(waffleCoordinator)
                    .environment(storeManager)
                    .modelContainer(container)
            } else {
                Text("Oh, how'd you do that?\nPlease close this window. - Waffle")
                    .multilineTextAlignment(.center)
            }
        }
        .defaultSize(width: 420, height: 420)
        .windowResizability(.contentSize)
    }

    // MARK: - Review prompt logic

    private func handleScenePhaseChange(_ newPhase: ScenePhase) {
        switch newPhase {
        case .active:
            // Increment launch count once per process run, at first activation.
            if !didIncrementThisRun {
                didIncrementThisRun = true
                launchCount += 1
            }

            // Attempt review on specific milestones (5th launch here).
            if !attemptedReviewThisActivation, launchCount == 5 {
                attemptedReviewThisActivation = true
                requestReviewIfAppropriate()
            }

        case .inactive, .background:
            // Reset per-activation guard so we could consider showing at a later activation if needed.
            attemptedReviewThisActivation = false

        @unknown default:
            break
        }
    }

    private func requestReviewIfAppropriate() {
        // Find a foreground active UIWindowScene
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }) else {
            // Fallback: requestReview() is deprecated, but no active scene was found.
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                AppStore.requestReview(in: windowScene)
            }
            return
        }
        AppStore.requestReview(in: scene)
    }
}
