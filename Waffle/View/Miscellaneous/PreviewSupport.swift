//
//  PreviewSupport.swift
//  Waffle
//
//  Shared dependency builders for SwiftUI previews.
//

#if DEBUG
import Foundation
import SwiftData

@MainActor
enum PreviewSupport {
    /// An in-memory SwiftData container for previews.
    static func makeContainer() -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try! ModelContainer(for: Bookmark.self, Preset.self, configurations: config)
    }

    /// A fully wired coordinator backed by an in-memory container.
    static func makeCoordinator(container: ModelContainer? = nil) -> WaffleCoordinator {
        let container = container ?? makeContainer()
        let errorHandler = ErrorHandler()
        return WaffleCoordinator(
            store: StoreManager(),
            library: LibraryManager(container: container, errorHandler: errorHandler),
            errorHandler: errorHandler,
            waffleState: WaffleState()
        )
    }

    /// Seeds the container with sample bookmarks and presets.
    static func seedSampleLibrary(in container: ModelContainer) {
        let context = container.mainContext

        let presets = [
            Preset(name: "News 2x2", rows: 2, cols: 2, urls: [
                "https://www.apple.com", "https://www.bbc.com",
                "https://www.cnn.com", "https://www.theverge.com"
            ]),
            Preset(name: "Work 1x3", rows: 1, cols: 3, urls: [
                "https://mail.google.com", "https://calendar.google.com", "https://github.com"
            ])
        ]
        presets.forEach { context.insert($0) }

        let bookmarks = [
            Bookmark(url: URL(string: "https://apple.com")!, title: "Apple"),
            Bookmark(url: URL(string: "https://developer.apple.com/documentation")!, title: "Documentation"),
            Bookmark(url: URL(string: "https://news.ycombinator.com")!, title: "Hacker News"),
            Bookmark(url: URL(string: "https://github.com")!, title: "GitHub")
        ]
        for (index, bookmark) in bookmarks.enumerated() {
            bookmark.sortIndex = index
            context.insert(bookmark)
        }

        try? context.save()
    }
}
#endif
