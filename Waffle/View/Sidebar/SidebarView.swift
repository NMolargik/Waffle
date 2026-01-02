//
//  SidebarView.swift
//  Waffle
//
//  Created by Nick Molargik on 9/2/25.
//

import SwiftUI
import SwiftData

struct SidebarView: View {
    @Environment(\.modelContext) private var context

    // Sort by user-defined order; as a fallback for legacy data where sortIndex may be equal,
    // also sort by createdAt to keep a stable order.
    @Query(sort: [
        SortDescriptor(\Bookmark.sortIndex, order: .forward),
        SortDescriptor(\Bookmark.createdAt, order: .reverse)
    ])
    private var bookmarks: [Bookmark]
    @Query(sort: \Preset.createdAt, order: .reverse) private var presets: [Preset]

    var applyPreset: (Preset) -> Void
    var savePreset: (_ withName: String?) -> Void
    var applyBookmark: (Bookmark) -> Void
    var saveBookmark: (_ urlString: String, _ withTitle: String?) -> Void
    var overwritePreset: (Preset) -> Void

    @State private var searchText: String = ""
    @State private var showingPresetNamePrompt = false
    @State private var newPresetName: String = ""
    @State private var showingBookmarkNamePrompt = false
    @State private var newBookmarkTitle: String = ""
    @State private var newBookmarkURLString: String = ""
    @State private var bookmarkToEdit: Bookmark? = nil

    var body: some View {
        VStack {
            BookmarksHeaderView(
                onQuickSaveCurrent: { saveBookmark("", nil) },
                onSaveAs: { beginBookmarkCreation() }
            )
            bookmarksListView

            PresetsHeaderView(
                onQuickSave: { savePreset(nil) },
                onSaveAs: { beginPresetNaming() }
            )

            PresetsListView(
                presets: filteredPresets,
                applyPreset: applyPreset,
                overwritePreset: overwritePreset,
                onRename: { preset in beginPresetRenaming(existingName: preset.name) },
                onDelete: { preset in
                    context.delete(preset)
                    try? context.save()
                }
            )
        }
        .searchable(text: $searchText, prompt: "Search bookmarks & presets")
        .alert("Save Preset", isPresented: $showingPresetNamePrompt) {
            TextField("Name", text: $newPresetName)
            Button("Cancel", role: .cancel) { resetPresetPrompt() }
            Button("Save") {
                savePreset(newPresetName.isEmpty ? nil : newPresetName)
                resetPresetPrompt()
            }
        } message: {
            Text("Enter a name for this grid layout.")
        }
        .alert(bookmarkToEdit == nil ? "Save Bookmark" : "Rename Bookmark", isPresented: $showingBookmarkNamePrompt) {
            TextField("Title", text: $newBookmarkTitle)
            TextField("URL", text: $newBookmarkURLString)
                .textContentType(.URL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            Button("Cancel", role: .cancel) {
                resetBookmarkPrompt()
            }
            Button(bookmarkToEdit == nil ? "Save" : "Update") {
                if let editing = bookmarkToEdit {
                    editing.title = newBookmarkTitle
                    editing.urlString = newBookmarkURLString
                    try? context.save()
                } else {
                    let new = Bookmark(
                        url: URL(string: newBookmarkURLString) ?? URL(string: "https://apple.com")!,
                        title: newBookmarkTitle
                    )
                    new.sortIndex = (bookmarks.map(\.sortIndex).max() ?? -1) + 1
                    context.insert(new)
                    try? context.save()
                }
                resetBookmarkPrompt()
            }
        } message: {
            Text(bookmarkToEdit == nil ? "Enter a title and URL for this bookmark." : "Edit the title and URL for this bookmark.")
        }
        .onAppear {
            normalizeSortIndexesIfNeeded()
        }
    }

    // MARK: - Filtered Data

    private var filteredBookmarks: [Bookmark] {
        guard !searchText.isEmpty else { return bookmarks }
        let query = searchText.lowercased()
        return bookmarks.filter {
            $0.title.lowercased().contains(query) ||
            $0.urlString.lowercased().contains(query)
        }
    }

    private var filteredPresets: [Preset] {
        guard !searchText.isEmpty else { return presets }
        let query = searchText.lowercased()
        return presets.filter { $0.name.lowercased().contains(query) }
    }

    // MARK: - Subviews

    @ViewBuilder
    private var bookmarksListView: some View {
        let moveHandler: ((IndexSet, Int) -> Void)? = searchText.isEmpty ? { from, to in
            handleMove(from: from, to: to)
        } : nil

        BookmarksListView(
            bookmarks: filteredBookmarks,
            applyBookmark: applyBookmark,
            onEdit: { bm in beginBookmarkEditing(bm) },
            onDelete: { bm in
                context.delete(bm)
                try? context.save()
                normalizeSortIndexesIfNeeded()
            },
            onMove: moveHandler
        )
    }

    // MARK: - Preset Prompt

    private func beginPresetNaming() {
        newPresetName = ""
        showingPresetNamePrompt = true
    }

    private func beginPresetRenaming(existingName: String) {
        newPresetName = existingName
        showingPresetNamePrompt = true
    }

    private func resetPresetPrompt() {
        showingPresetNamePrompt = false
        newPresetName = ""
    }

    // MARK: - Bookmark Prompt

    private func beginBookmarkCreation() {
        bookmarkToEdit = nil
        newBookmarkTitle = ""
        newBookmarkURLString = ""
        showingBookmarkNamePrompt = true
    }

    private func beginBookmarkEditing(_ bookmark: Bookmark) {
        bookmarkToEdit = bookmark
        newBookmarkTitle = bookmark.title
        newBookmarkURLString = bookmark.urlString
        showingBookmarkNamePrompt = true
    }

    private func resetBookmarkPrompt() {
        showingBookmarkNamePrompt = false
        bookmarkToEdit = nil
        newBookmarkTitle = ""
        newBookmarkURLString = ""
    }

    // MARK: - Sort Index Management

    private func normalizeSortIndexesIfNeeded() {
        for (idx, bm) in bookmarks.enumerated() where bm.sortIndex != idx {
            bm.sortIndex = idx
        }
        try? context.save()
    }

    private func handleMove(from source: IndexSet, to destination: Int) {
        var ordered = bookmarks
        ordered.move(fromOffsets: source, toOffset: destination)
        for (idx, bm) in ordered.enumerated() {
            bm.sortIndex = idx
        }
        try? context.save()
    }
}

private enum SidebarPreviewData {
    static func makePreviewContainer() -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: Bookmark.self, Preset.self, configurations: config)
        let context = container.mainContext

        let p1 = Preset(name: "News 2x2", rows: 2, cols: 2, urls: [
            "https://www.apple.com",
            "https://www.bbc.com",
            "https://www.cnn.com",
            "https://www.theverge.com"
        ])
        let p2 = Preset(name: "Work 1x3", rows: 1, cols: 3, urls: [
            "https://mail.google.com",
            "https://calendar.google.com",
            "https://github.com"
        ])
        let p3 = Preset(name: "Research 3x2", rows: 3, cols: 2, urls: [
            "https://developer.apple.com",
            "https://swift.org",
            "https://forums.swift.org",
            "https://www.raywenderlich.com",
            "https://stackoverflow.com",
            "https://www.hackingwithswift.com"
        ])

        let b1 = Bookmark(url: URL(string: "https://apple.com")!, title: "Apple")
        let b2 = Bookmark(url: URL(string: "https://developer.apple.com/documentation")!, title: "Documentation")
        let b3 = Bookmark(url: URL(string: "https://news.ycombinator.com")!, title: "Hacker News")
        let b4 = Bookmark(url: URL(string: "https://github.com")!, title: "GitHub")
        b1.sortIndex = 0
        b2.sortIndex = 1
        b3.sortIndex = 2
        b4.sortIndex = 3

        context.insert(p1); context.insert(p2); context.insert(p3)
        context.insert(b1); context.insert(b2); context.insert(b3); context.insert(b4)
        try? context.save()
        return container
    }
}

#Preview {
    SidebarView(
        applyPreset: { _ in },
        savePreset: { _ in },
        applyBookmark: { _ in },
        saveBookmark: { _, _ in },
        overwritePreset: { _ in }
    )
    .frame(width: 500)
    .modelContainer(SidebarPreviewData.makePreviewContainer())
    .environment(WaffleCoordinator(store: StoreManager()))
}
