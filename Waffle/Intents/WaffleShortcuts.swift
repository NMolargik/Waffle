//
//  WaffleShortcuts.swift
//  Waffle
//
//  App Shortcuts surfaced in Siri, Spotlight, and the Shortcuts app
//  without any user setup.
//

import AppIntents

struct WaffleShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: OpenPresetIntent(),
            phrases: [
                "Open a preset in \(.applicationName)",
                "Open \(\.$preset) in \(.applicationName)",
                "Apply my \(\.$preset) preset in \(.applicationName)"
            ],
            shortTitle: "Open Preset",
            systemImageName: "square.grid.3x3.fill"
        )
        AppShortcut(
            intent: OpenBookmarkIntent(),
            phrases: [
                "Open a bookmark in \(.applicationName)",
                "Open \(\.$bookmark) in \(.applicationName)"
            ],
            shortTitle: "Open Bookmark",
            systemImageName: "bookmark.fill"
        )
        AppShortcut(
            intent: BookmarkCurrentPageIntent(),
            phrases: [
                "Bookmark this page in \(.applicationName)",
                "Save the current page in \(.applicationName)"
            ],
            shortTitle: "Bookmark Page",
            systemImageName: "bookmark.circle.fill"
        )
        AppShortcut(
            intent: SetGridSizeIntent(),
            phrases: [
                "Resize the \(.applicationName) grid",
                "Change the grid size in \(.applicationName)"
            ],
            shortTitle: "Resize Grid",
            systemImageName: "square.split.2x2"
        )
    }
}
