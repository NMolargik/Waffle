//
//  WaffleApp.swift
//  Waffle
//
//  Created by Nick Molargik on 8/30/25.
//

import AppIntents
import SwiftUI
import SwiftData
import WebKit
import os

@main
struct WaffleApp: App {
    @Environment(\.scenePhase) private var scenePhase

    private let container: ModelContainer
    private let storeManager: StoreManager
    private let coordinator: WaffleCoordinator

    private let reviewRequester: ReviewRequesting = AppStoreReviewRequester()

    // Review prompt tracking
    @AppStorage("launchCount") private var launchCount: Int = 0
    @State private var didIncrementThisRun: Bool = false

    init() {
        container = Self.makeModelContainer()

        let errorHandler = ErrorHandler()
        let store = StoreManager()
        let library = LibraryManager(container: container, errorHandler: errorHandler)
        let state = WaffleState()

        storeManager = store
        let coordinator = WaffleCoordinator(
            store: store,
            library: library,
            errorHandler: errorHandler,
            waffleState: state
        )
        self.coordinator = coordinator

        // Expose managers to App Intents (Siri, Shortcuts, Spotlight actions).
        AppDependencyManager.shared.add(dependency: library)
        AppDependencyManager.shared.add(dependency: coordinator)

        // Keep Spotlight's semantic index in sync with the library.
        let indexer = CoreSpotlightIndexer()
        library.libraryDidChange = {
            indexer.reindex(
                presets: library.presets().map(PresetEntity.init),
                bookmarks: library.bookmarks().map(BookmarkEntity.init)
            )
        }
    }

    /// Builds the SwiftData container, degrading gracefully when CloudKit is
    /// unavailable: CloudKit-synced → local-only → in-memory.
    private static func makeModelContainer() -> ModelContainer {
        let schema = Schema([Bookmark.self, Preset.self])

        do {
            let cloud = ModelConfiguration(
                "iCloud.com.molargiksoftware.Waffle",
                schema: schema,
                cloudKitDatabase: .private("iCloud.com.molargiksoftware.Waffle")
            )
            return try ModelContainer(for: schema, configurations: cloud)
        } catch {
            Log.app.error("CloudKit container unavailable, falling back to local store: \(error.localizedDescription)")
        }

        do {
            let local = ModelConfiguration(schema: schema, cloudKitDatabase: .none)
            return try ModelContainer(for: schema, configurations: local)
        } catch {
            Log.app.fault("Local store unavailable, falling back to in-memory: \(error.localizedDescription)")
        }

        do {
            let memory = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            return try ModelContainer(for: schema, configurations: memory)
        } catch {
            fatalError("Failed to create even an in-memory ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup(id: "main") {
            RootView()
                .frame(minWidth: 820, minHeight: 520)
                .modelContainer(container)
                .environment(coordinator)
                .environment(storeManager)
                .onChange(of: scenePhase) { _, newPhase in
                    handleScenePhaseChange(newPhase)
                }
                .onOpenURL { url in
                    guard let link = DeepLink(url: url) else { return }
                    coordinator.handle(link)
                }
                .task {
                    // Seed the Spotlight index (covers items synced via CloudKit
                    // while the app wasn't running).
                    coordinator.library.libraryDidChange?()
                }
        }
        .defaultSize(width: 1100, height: 800)
        .windowResizability(.contentMinSize)
        .handlesExternalEvents(matching: ["main"])
        .commands {
            WaffleCommands(coordinator: coordinator)
        }

        WindowGroup(id: "DetachedWaffleCell", for: WaffleCell.self) { $waffleCell in
            DetachedCellSceneHost(
                waffleCell: $waffleCell,
                storeManager: storeManager,
                container: container,
                coordinator: coordinator
            )
        }
        .defaultSize(width: 600, height: 600)
        .windowResizability(.contentMinSize)
        .handlesExternalEvents(matching: ["DetachedWaffleCell"])
    }

    // MARK: - Review prompt logic

    private func handleScenePhaseChange(_ newPhase: ScenePhase) {
        guard newPhase == .active else { return }

        // Increment launch count once per process run, at first activation.
        if !didIncrementThisRun {
            didIncrementThisRun = true
            launchCount += 1

            // Ask for a review at the fifth launch milestone.
            if launchCount == 5 {
                reviewRequester.requestReview()
            }
        }
    }

}

// MARK: - Detached Cell Scene

private struct DetachedCellSceneHost: View {
    @Environment(\.openWindow) private var openWindow

    @Binding var waffleCell: WaffleCell?
    let storeManager: StoreManager
    let container: ModelContainer
    let coordinator: WaffleCoordinator

    var body: some View {
        if let waffleCell {
            DetachedWaffleCellView(waffleCell: waffleCell)
                .environment(coordinator)
                .environment(storeManager)
                .modelContainer(container)
                .task {
                    // If only this detached window survived relaunch, bring
                    // the main window back once scene restoration settles.
                    try? await Task.sleep(for: .milliseconds(500))
                    if coordinator.mainWindowCount == 0 {
                        openWindow(id: "main")
                    }
                }
                .onDisappear {
                    // Safety net: return the popped cell to the grid when this
                    // window closes (e.g. the user swipes the window away).
                    if coordinator.waffleState.poppedCell != nil {
                        let address = waffleCell.address.isEmpty
                            ? (waffleCell.page.url?.absoluteString ?? "")
                            : waffleCell.address
                        coordinator.waffleState.popBack(poppedCellAddress: address)
                    }

                    // Reopen the main window only when none is left. Delay
                    // slightly to avoid WebKit animation race conditions.
                    Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(200))
                        if coordinator.mainWindowCount == 0 {
                            openWindow(id: "main")
                        }
                    }
                }
        } else {
            Text("Oh, how'd you do that?\nPlease close this window. - Waffle")
                .multilineTextAlignment(.center)
        }
    }
}
