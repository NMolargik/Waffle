//
//  WaffleApp.swift
//  Waffle
//
//  Thin shell: builds the SessionController (composition root in WaffleComposition),
//  registers it for App Intents, and hosts the two scenes. All feature code lives in
//  Packages/Waffle.
//

import AppIntents
import SwiftData
import SwiftUI
import WaffleComposition
import WaffleCore
import WaffleData
import WaffleFeatureGrid
import WaffleServices
import WebKit

@main
struct WaffleApp: App {
    @Environment(\.scenePhase) private var scenePhase

    private let session: SessionController

    private let reviewRequester: ReviewRequesting = AppStoreReviewRequester()

    // Review prompt tracking
    @AppStorage("launchCount") private var launchCount: Int = 0
    @State private var didIncrementThisRun: Bool = false

    init() {
        let session = SessionController(
            presetDonator: WafflePresetDonator(),
            indexer: CoreSpotlightIndexer(),
            activityAnnotator: BrowsingActivityAnnotator()
        )
        self.session = session

        // Expose the session to App Intents (Siri, Shortcuts, Spotlight actions).
        AppDependencyManager.shared.add(dependency: session)
    }

    var body: some Scene {
        WindowGroup(id: "main") {
            RootView(session: session)
                .frame(minWidth: 820, minHeight: 520)
                .modelContainer(session.container)
                .onChange(of: scenePhase) { _, newPhase in
                    handleScenePhaseChange(newPhase)
                }
                .onOpenURL { url in
                    guard let link = DeepLink(url: url) else { return }
                    session.handle(link)
                }
                .task {
                    // Seed the Spotlight index (covers items synced via CloudKit
                    // while the app wasn't running).
                    session.reindexLibrary()
                }
        }
        .defaultSize(width: 1100, height: 800)
        .windowResizability(.contentMinSize)
        .handlesExternalEvents(matching: ["main"])
        .commands {
            WaffleCommands(session: session)
        }

        WindowGroup(id: "DetachedWaffleCell", for: WaffleCell.self) { $waffleCell in
            DetachedCellSceneHost(waffleCell: $waffleCell, session: session)
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
    let session: SessionController

    var body: some View {
        if let waffleCell {
            DetachedWaffleCellView(
                waffleCell: waffleCell,
                onPopBack: { address in
                    session.grid.popBack(poppedCellAddress: address)
                },
                shouldReopenMainWindow: { session.mainWindowCount == 0 }
            )
            .modelContainer(session.container)
            .task {
                // If only this detached window survived relaunch, bring
                // the main window back once scene restoration settles.
                try? await Task.sleep(for: .milliseconds(500))
                if session.mainWindowCount == 0 {
                    openWindow(id: "main")
                }
            }
            .onDisappear {
                // Safety net: return the popped cell to the grid when this
                // window closes (e.g. the user swipes the window away).
                if session.grid.poppedCell != nil {
                    let address = waffleCell.address.isEmpty
                        ? (waffleCell.page.url?.absoluteString ?? "")
                        : waffleCell.address
                    session.grid.popBack(poppedCellAddress: address)
                }

                // Reopen the main window only when none is left. Delay
                // slightly to avoid WebKit animation race conditions.
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(200))
                    if session.mainWindowCount == 0 {
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
