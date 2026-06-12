//
//  SidebarView.swift
//  Waffle
//
//  Created by Nick Molargik on 9/2/25.
//

import SwiftUI
import SwiftData
import WebKit

struct SidebarView: View {
    @Environment(WaffleCoordinator.self) private var coordinator

    // Sort by user-defined order; as a fallback for legacy data where sortIndex may be equal,
    // also sort by createdAt to keep a stable order.
    @Query(sort: [
        SortDescriptor(\Bookmark.sortIndex, order: .forward),
        SortDescriptor(\Bookmark.createdAt, order: .reverse)
    ])
    private var bookmarks: [Bookmark]
    @Query(sort: \Preset.createdAt, order: .reverse) private var presets: [Preset]

    @State private var searchText: String = ""
    @State private var showingPresetNamePrompt = false
    @State private var newPresetName: String = ""
    @State private var presetToRename: Preset? = nil
    @State private var showingBookmarkNamePrompt = false
    @State private var newBookmarkTitle: String = ""
    @State private var newBookmarkURLString: String = ""
    @State private var bookmarkToEdit: Bookmark? = nil

    private var library: LibraryManager { coordinator.library }
    private var waffleState: WaffleState { coordinator.waffleState }

    var body: some View {
        VStack {
            BookmarksHeaderView(
                onQuickSaveCurrent: { quickSaveBookmark() },
                onSaveAs: { beginBookmarkCreation() }
            )
            bookmarksListView

            PresetsHeaderView(
                onQuickSave: { savePreset(named: nil) },
                onSaveAs: { beginPresetNaming() }
            )

            PresetsListView(
                presets: filteredPresets,
                applyPreset: { coordinator.applyPreset($0) },
                overwritePreset: { overwritePreset($0) },
                onRename: { beginPresetRenaming($0) },
                onDelete: { library.deletePreset($0) }
            )
        }
        .searchable(text: $searchText, prompt: Text("Search bookmarks & presets"))
        .alert(presetToRename == nil ? Text("Save Preset") : Text("Rename Preset"), isPresented: $showingPresetNamePrompt) {
            TextField(String(localized: "Name"), text: $newPresetName)
            Button(String(localized: "Cancel"), role: .cancel) { resetPresetPrompt() }
            Button(presetToRename == nil ? String(localized: "Save") : String(localized: "Rename")) {
                if let preset = presetToRename {
                    library.renamePreset(preset, to: newPresetName)
                } else {
                    savePreset(named: newPresetName.isEmpty ? nil : newPresetName)
                }
                resetPresetPrompt()
            }
        } message: {
            Text("Enter a name for this grid layout.")
        }
        .alert(bookmarkToEdit == nil ? Text("Save Bookmark") : Text("Rename Bookmark"), isPresented: $showingBookmarkNamePrompt) {
            TextField(String(localized: "Title"), text: $newBookmarkTitle)
            TextField(String(localized: "URL"), text: $newBookmarkURLString)
                .textContentType(.URL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            Button(String(localized: "Cancel"), role: .cancel) {
                resetBookmarkPrompt()
            }
            Button(bookmarkToEdit == nil ? String(localized: "Save") : String(localized: "Update")) {
                if let editing = bookmarkToEdit {
                    library.updateBookmark(editing, title: newBookmarkTitle, urlString: newBookmarkURLString)
                } else {
                    library.addBookmark(urlString: newBookmarkURLString, title: newBookmarkTitle)
                }
                resetBookmarkPrompt()
            }
        } message: {
            Text(bookmarkToEdit == nil ? "Enter a title and URL for this bookmark." : "Edit the title and URL for this bookmark.")
        }
        .onAppear {
            library.normalizeBookmarkSortIndexes()
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

    @ContentBuilder
    private var bookmarksListView: some View {
        let moveHandler: ((IndexSet, Int) -> Void)? = searchText.isEmpty ? { from, to in
            library.moveBookmarks(bookmarks, from: from, to: to)
        } : nil

        BookmarksListView(
            bookmarks: filteredBookmarks,
            applyBookmark: { bookmark in
                waffleState.loadInSelectedCell(bookmark.urlString)
            },
            onEdit: { beginBookmarkEditing($0) },
            onDelete: { library.deleteBookmark($0) },
            onMove: moveHandler
        )
    }

    // MARK: - Actions

    private func quickSaveBookmark() {
        guard let cell = waffleState.selectedCell else { return }
        library.addBookmark(urlString: cell.address, title: cell.page.title)
    }

    private func savePreset(named name: String?) {
        guard coordinator.canMakePresets else {
            coordinator.requestSyrup()
            return
        }
        library.savePreset(
            named: name,
            rows: waffleState.rowCount,
            cols: waffleState.colCount,
            urls: waffleState.flattenedAddresses()
        )
    }

    private func overwritePreset(_ preset: Preset) {
        guard coordinator.canMakePresets else {
            coordinator.requestSyrup()
            return
        }
        library.overwritePreset(
            preset,
            rows: waffleState.rowCount,
            cols: waffleState.colCount,
            urls: waffleState.flattenedAddresses()
        )
    }

    // MARK: - Preset Prompt

    private func beginPresetNaming() {
        guard coordinator.canMakePresets else {
            coordinator.requestSyrup()
            return
        }
        presetToRename = nil
        newPresetName = ""
        showingPresetNamePrompt = true
    }

    private func beginPresetRenaming(_ preset: Preset) {
        presetToRename = preset
        newPresetName = preset.name
        showingPresetNamePrompt = true
    }

    private func resetPresetPrompt() {
        showingPresetNamePrompt = false
        presetToRename = nil
        newPresetName = ""
    }

    // MARK: - Bookmark Prompt

    private func beginBookmarkCreation() {
        bookmarkToEdit = nil
        newBookmarkTitle = ""
        newBookmarkURLString = waffleState.selectedCell?.address ?? ""
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
}

#Preview {
    let container = PreviewSupport.makeContainer()
    PreviewSupport.seedSampleLibrary(in: container)

    return SidebarView()
        .frame(width: 500)
        .modelContainer(container)
        .environment(PreviewSupport.makeCoordinator(container: container))
}
