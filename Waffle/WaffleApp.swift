//
//  WaffleApp.swift
//  Waffle
//
//  Created by Nick Molargik on 8/30/25.
//

import SwiftUI
import SwiftData
import StoreKit
import WebKit

@main
struct WaffleApp: App {
    private let container: ModelContainer
    private let storeManager = StoreManager()
    private let coordinator: WaffleCoordinator

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
            self.coordinator = WaffleCoordinator(store: storeManager)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup(id: "main") {
            MainSceneHost(storeManager: storeManager, container: container, coordinator: coordinator)
                .onChange(of: scenePhase) { _, newPhase in
                    handleScenePhaseChange(newPhase)
                }
        }
        .defaultSize(width: 520, height: 520)
        .windowResizability(.contentSize)
        .handlesExternalEvents(matching: ["main"])
        .commands { }

        WindowGroup(id: "DetachedWaffleCell", for: WaffleCell.self) { $waffleCell in
            DetachedCellSceneHost(waffleCell: $waffleCell, storeManager: storeManager, container: container, coordinator: coordinator)
        }
        .defaultSize(width: 420, height: 420)
        .windowResizability(.contentSize)
        .handlesExternalEvents(matching: ["DetachedWaffleCell"])
        .commands { }
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

// MARK: - Scene Hosts
private struct MainSceneHost: View {
    let storeManager: StoreManager
    let container: ModelContainer
    let coordinator: WaffleCoordinator

    init(storeManager: StoreManager, container: ModelContainer, coordinator: WaffleCoordinator) {
        self.storeManager = storeManager
        self.container = container
        self.coordinator = coordinator
    }

    var body: some View {
        RootView()
            .frame(minWidth: 820)
            .modelContainer(container)
            .environment(coordinator)
            .environment(storeManager)
    }
}

private struct DetachedCellSceneHost: View {
    @Binding var waffleCell: WaffleCell?
    let storeManager: StoreManager
    let container: ModelContainer
    let coordinator: WaffleCoordinator

    init(waffleCell: Binding<WaffleCell?>, storeManager: StoreManager, container: ModelContainer, coordinator: WaffleCoordinator) {
        self._waffleCell = waffleCell
        self.storeManager = storeManager
        self.container = container
        self.coordinator = coordinator
    }

    var body: some View {
        if let waffleCell {
            DetachedWaffleCellView(waffleCell: waffleCell)
                .environment(coordinator)
                .environment(storeManager)
                .modelContainer(container)
                .onDisappear {
                    // Ensure the popped cell is returned to the grid when this window closes.
                    let addr = waffleCell.address.isEmpty ? (waffleCell.page.url?.absoluteString ?? "") : waffleCell.address
                    if !addr.isEmpty {
                        coordinator.waffleState.popBack(poppedCellAddress: addr)
                    }
                }
        } else {
            Text("Oh, how'd you do that?\nPlease close this window. - Waffle")
                .multilineTextAlignment(.center)
        }
    }
}

