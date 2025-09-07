//
//  WaffleApp.swift
//  Waffle
//
//  Created by Nick Molargik on 8/30/25.
//

import SwiftUI
import SwiftData

@main
struct WaffleApp: App {
    private let container: ModelContainer
    private let storeManager = StoreManager()
    @State private var waffleCoordinator: WaffleCoordinator

    private let appGroup = "group.com.molargiksoftware.Waffle"

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
}
