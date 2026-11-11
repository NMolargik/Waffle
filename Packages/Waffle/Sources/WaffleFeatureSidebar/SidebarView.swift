//
//  SidebarView.swift
//  WaffleFeatureSidebar
//
//  Bookmarks + presets sidebar. Data flows through `SidebarModel` (use-cases); grid
//  interplay and Syrup gating arrive as injected closures from the composition root.
//

#if os(iOS)
import SwiftUI
import WaffleCore
import WaffleDesignSystem

public struct SidebarView: View {
    @Bindable private var model: SidebarModel

    /// Gated preset application (session presents the Syrup sheet when locked).
    let applyPreset: (Preset) -> Void
    /// Loads a URL into the selected grid cell.
    let applyBookmark: (String) -> Void
    /// The live grid layout, captured when saving/overwriting a preset.
    let currentGrid: () -> (rows: Int, cols: Int, urls: [String], refreshIntervals: [Int], paneCount: Int, paneRatios: [Double])
    /// The selected cell's address/title, captured when quick-saving a bookmark.
    let currentCell: () -> (address: String, title: String)?
    let isSyrupEnabled: Bool
    let canMakePresets: Bool
    let requestSyrup: () -> Void
    /// iPhone and Duo: saved layouts are free to open, and the free plan may save one.
    /// (iPad presets stay entirely Syrup.)
    let isPhoneLayouts: Bool

    @State private var showingPresetNamePrompt = false
    @State private var newPresetName: String = ""
    @State private var presetToRename: Preset? = nil
    @State private var showingBookmarkNamePrompt = false
    @State private var newBookmarkTitle: String = ""
    @State private var newBookmarkURLString: String = ""
    @State private var bookmarkToEdit: Bookmark? = nil

    public init(
        model: SidebarModel,
        applyPreset: @escaping (Preset) -> Void,
        applyBookmark: @escaping (String) -> Void,
        currentGrid: @escaping () -> (rows: Int, cols: Int, urls: [String], refreshIntervals: [Int], paneCount: Int, paneRatios: [Double]),
        currentCell: @escaping () -> (address: String, title: String)?,
        isSyrupEnabled: Bool,
        canMakePresets: Bool,
        requestSyrup: @escaping () -> Void,
        isPhoneLayouts: Bool = false
    ) {
        self.model = model
        self.applyPreset = applyPreset
        self.applyBookmark = applyBookmark
        self.currentGrid = currentGrid
        self.currentCell = currentCell
        self.isSyrupEnabled = isSyrupEnabled
        self.canMakePresets = canMakePresets
        self.requestSyrup = requestSyrup
        self.isPhoneLayouts = isPhoneLayouts
    }

    public var body: some View {
        Group {
            if isPhoneLayouts {
                phoneContent
            } else {
                gridContent
            }
        }
        .searchable(
            text: $model.searchText,
            prompt: isPhoneLayouts ? Text("Search bookmarks & layouts") : Text("Search bookmarks & presets")
        )
        .alert(presetToRename == nil ? Text(LocalizedStringKey(isPhoneLayouts ? "Save Layout" : "Save Preset")) : Text(LocalizedStringKey(isPhoneLayouts ? "Rename Layout" : "Rename Preset")), isPresented: $showingPresetNamePrompt) {
            TextField(String(localized: "Name"), text: $newPresetName)
            Button(String(localized: "Cancel"), role: .cancel) { resetPresetPrompt() }
            Button(presetToRename == nil ? String(localized: "Save") : String(localized: "Rename")) {
                if let preset = presetToRename {
                    model.renamePreset(preset, to: newPresetName)
                } else {
                    savePreset(named: newPresetName.isEmpty ? nil : newPresetName)
                }
                resetPresetPrompt()
            }
        } message: {
            Text(LocalizedStringKey(isPhoneLayouts ? "Enter a name for this layout." : "Enter a name for this grid layout."))
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
                    model.updateBookmark(editing, title: newBookmarkTitle, urlString: newBookmarkURLString)
                } else {
                    model.addBookmark(urlString: newBookmarkURLString, title: newBookmarkTitle)
                }
                resetBookmarkPrompt()
            }
        } message: {
            Text(bookmarkToEdit == nil ? "Enter a title and URL for this bookmark." : "Edit the title and URL for this bookmark.")
        }
        .onAppear {
            model.load()
            model.normalizeBookmarkOrder()
        }
    }

    // MARK: - Content

    private var phoneContent: some View {
        PhoneLayoutsView(
            presets: model.filteredPresets,
            hasAnyPresets: !model.presets.isEmpty,
            bookmarks: model.filteredBookmarks,
            hasAnyBookmarks: !model.bookmarks.isEmpty,
            canSaveAnotherLayout: canMakePresets,
            requestSyrup: requestSyrup,
            onSaveOpenPanes: { savePreset(named: nil) },
            onSaveLayoutAs: { beginPresetNaming() },
            applyPreset: { applyPreset($0) },
            // Updating a layout you already have is not adding one: free for everyone.
            updatePreset: { updatePhoneLayout($0) },
            onRename: { beginPresetRenaming($0) },
            onDeletePreset: { model.deletePreset($0) },
            onBookmarkCurrentPage: { quickSaveBookmark() },
            onSaveBookmarkAs: { beginBookmarkCreation() },
            applyBookmark: { applyBookmark($0.urlString) },
            onEditBookmark: { beginBookmarkEditing($0) },
            onDeleteBookmark: { model.deleteBookmark($0) },
            onMoveBookmarks: model.canReorderBookmarks ? { from, to in model.moveBookmarks(from: from, to: to) } : nil
        )
    }

    private var gridContent: some View {
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
                presets: model.filteredPresets,
                isSyrupEnabled: isSyrupEnabled,
                requestSyrup: requestSyrup,
                applyPreset: { applyPreset($0) },
                overwritePreset: { overwritePreset($0) },
                onRename: { beginPresetRenaming($0) },
                onDelete: { model.deletePreset($0) }
            )
        }
    }

    // MARK: - Subviews

    @ContentBuilder
    private var bookmarksListView: some View {
        let moveHandler: ((IndexSet, Int) -> Void)? = model.canReorderBookmarks ? { from, to in
            model.moveBookmarks(from: from, to: to)
        } : nil

        BookmarksListView(
            bookmarks: model.filteredBookmarks,
            applyBookmark: { bookmark in
                applyBookmark(bookmark.urlString)
            },
            onEdit: { beginBookmarkEditing($0) },
            onDelete: { model.deleteBookmark($0) },
            onMove: moveHandler
        )
    }

    // MARK: - Actions

    private func quickSaveBookmark() {
        guard let cell = currentCell() else { return }
        model.addBookmark(urlString: cell.address, title: cell.title)
    }

    private func savePreset(named name: String?) {
        guard canMakePresets else {
            requestSyrup()
            return
        }
        let grid = currentGrid()
        // Phone layouts are named after their sites ("Wikipedia + Apple"), not a timestamp.
        let name = (isPhoneLayouts && (name ?? "").isEmpty)
            ? LayoutNaming.suggestedName(addresses: grid.urls, existingNames: model.presets.map(\.name))
            : name
        model.savePreset(named: name, rows: grid.rows, cols: grid.cols, urls: grid.urls, refreshIntervals: grid.refreshIntervals, paneCount: grid.paneCount, paneRatios: grid.paneRatios)
    }

    private func updatePhoneLayout(_ preset: Preset) {
        let grid = currentGrid()
        model.overwritePreset(preset, rows: grid.rows, cols: grid.cols, urls: grid.urls, refreshIntervals: grid.refreshIntervals, paneCount: grid.paneCount, paneRatios: grid.paneRatios, announce: true)
    }

    private func overwritePreset(_ preset: Preset) {
        guard canMakePresets else {
            requestSyrup()
            return
        }
        let grid = currentGrid()
        model.overwritePreset(preset, rows: grid.rows, cols: grid.cols, urls: grid.urls, refreshIntervals: grid.refreshIntervals, paneCount: grid.paneCount, paneRatios: grid.paneRatios)
    }

    // MARK: - Preset Prompt

    private func beginPresetNaming() {
        guard canMakePresets else {
            requestSyrup()
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
        newBookmarkURLString = currentCell()?.address ?? ""
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
#endif
