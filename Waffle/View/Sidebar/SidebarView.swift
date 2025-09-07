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

    @State private var viewModel = SidebarView.ViewModel()

    var body: some View {
        VStack {
            BookmarksHeaderView(
                onQuickSaveCurrent: { saveBookmark("", nil) },
                onSaveAs: { viewModel.beginBookmarkCreation() }
            )
            
            BookmarksListView(
                bookmarks: bookmarks,
                applyBookmark: applyBookmark,
                onEdit: { bm in viewModel.beginBookmarkEditing(bm) },
                onDelete: { bm in
                    context.delete(bm)
                    try? context.save()
                    normalizeSortIndexesIfNeeded()
                },
                onMove: handleMove
            )
            
            PresetsHeaderView(
                onQuickSave: { savePreset(nil) },
                onSaveAs: { viewModel.beginPresetNaming() }
            )
            
            PresetsListView(
                presets: presets,
                applyPreset: applyPreset,
                overwritePreset: overwritePreset,
                onRename: { preset in viewModel.beginPresetRenaming(existingName: preset.name) },
                onDelete: { preset in
                    context.delete(preset)
                    try? context.save()
                }
            )

        }
        // Inline "Save Preset" alert
        .alert("Save Preset", isPresented: $viewModel.showingPresetNamePrompt) {
            TextField("Name", text: $viewModel.newPresetName)
            Button("Cancel", role: .cancel) { viewModel.resetPresetPrompt() }
            Button("Save") {
                savePreset(viewModel.newPresetName.isEmpty ? nil : viewModel.newPresetName)
                viewModel.resetPresetPrompt()
            }
        } message: {
            Text("Enter a name for this grid layout.")
        }
        // Inline Bookmark create/edit alert
        .alert(viewModel.bookmarkToEdit == nil ? "Save Bookmark" : "Rename Bookmark", isPresented: $viewModel.showingBookmarkNamePrompt) {
            TextField("Title", text: $viewModel.newBookmarkTitle)
            TextField("URL", text: $viewModel.newBookmarkURLString)
                .textContentType(.URL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            Button("Cancel", role: .cancel) {
                viewModel.resetBookmarkPrompt()
            }
            Button(viewModel.bookmarkToEdit == nil ? "Save" : "Update") {
                if let editing = viewModel.bookmarkToEdit {
                    // Update existing bookmark
                    editing.title = viewModel.newBookmarkTitle
                    editing.urlString = viewModel.newBookmarkURLString
                    try? context.save()
                } else {
                    // Create new bookmark at the end of the current order
                    let new = Bookmark(
                        url: URL(string: viewModel.newBookmarkURLString) ?? URL(string: "https://apple.com")!,
                        title: viewModel.newBookmarkTitle
                    )
                    new.sortIndex = (bookmarks.map(\.sortIndex).max() ?? -1) + 1
                    context.insert(new)
                    try? context.save()
                }
                viewModel.resetBookmarkPrompt()
            }
        } message: {
            Text(viewModel.bookmarkToEdit == nil ? "Enter a title and URL for this bookmark." : "Edit the title and URL for this bookmark.")
        }
        .onAppear {
            normalizeSortIndexesIfNeeded()
        }
    }

    // Ensure sortIndex is a contiguous 0...(n-1) sequence to keep moves predictable,
    // especially if some items were created before sortIndex existed.
    private func normalizeSortIndexesIfNeeded() {
        // Current order is already sorted by sortIndex (and createdAt fallback).
        for (idx, bm) in bookmarks.enumerated() where bm.sortIndex != idx {
            bm.sortIndex = idx
        }
        try? context.save()
    }

    // Persist reordering by updating sortIndex based on the drag result.
    private func handleMove(from source: IndexSet, to destination: Int) {
        // Make a working copy in current display order
        var ordered = bookmarks
        ordered.move(fromOffsets: source, toOffset: destination)
        // Reassign contiguous sortIndex by new order
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

