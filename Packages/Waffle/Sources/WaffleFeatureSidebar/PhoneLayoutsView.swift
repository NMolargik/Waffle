//
//  PhoneLayoutsView.swift
//  WaffleFeatureSidebar
//
//  The Layouts & Bookmarks list on iPhone and iPhone Duo: one list, saved layouts first, then
//  bookmarks. (The iPad keeps its two-section sidebar.) Every layout row has a visible
//  options button for rename, share, update and delete; the Syrup card for free users sits
//  after the layout they already saved, never above it.
//

#if os(iOS)
import SwiftUI
import WaffleCore
import WaffleDesignSystem

struct PhoneLayoutsView: View {
    var presets: [Preset]
    var hasAnyPresets: Bool
    var bookmarks: [Bookmark]
    var hasAnyBookmarks: Bool
    /// More layouts need Syrup (the free plan keeps one).
    var canSaveAnotherLayout: Bool
    var requestSyrup: () -> Void
    var onSaveOpenPanes: () -> Void
    var onSaveLayoutAs: () -> Void
    var applyPreset: (Preset) -> Void
    var updatePreset: (Preset) -> Void
    var onRename: (Preset) -> Void
    var onDeletePreset: (Preset) -> Void
    var onBookmarkCurrentPage: () -> Void
    var onSaveBookmarkAs: () -> Void
    var applyBookmark: (Bookmark) -> Void
    var onEditBookmark: (Bookmark) -> Void
    var onDeleteBookmark: (Bookmark) -> Void
    var onMoveBookmarks: ((IndexSet, Int) -> Void)?

    var body: some View {
        List {
            Section {
                ForEach(presets) { preset in
                    layoutRow(preset)
                }
                if !hasAnyPresets {
                    emptyLayouts
                }
                if !canSaveAnotherLayout {
                    upsell
                }
            } header: {
                sectionHeader(title: "Layouts", icon: "rectangle.split.2x1.fill") {
                    Button(action: onSaveOpenPanes) {
                        Label("Save Open Panes", systemImage: "square.and.arrow.down.fill")
                    }
                    Button(action: onSaveLayoutAs) {
                        Label("Save As…", systemImage: "square.and.pencil")
                    }
                }
            }

            Section {
                if bookmarks.isEmpty {
                    Text(hasAnyBookmarks ? "No bookmarks match your search" : "No bookmarks yet. Use New to save the page you are on.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(bookmarks) { bookmark in
                        bookmarkRow(bookmark)
                    }
                    .onMove { from, to in onMoveBookmarks?(from, to) }
                    .moveDisabled(onMoveBookmarks == nil)
                }
            } header: {
                sectionHeader(title: "Bookmarks", icon: "bookmark.fill") {
                    Button(action: onBookmarkCurrentPage) {
                        Label("Bookmark This Page", systemImage: "square.and.arrow.down.fill")
                    }
                    Button(action: onSaveBookmarkAs) {
                        Label("Save As…", systemImage: "square.and.pencil")
                    }
                }
            }
        }
    }

    // MARK: - Headers

    private func sectionHeader<MenuItems: View>(
        title: LocalizedStringKey,
        icon: String,
        @ViewBuilder menu: () -> MenuItems
    ) -> some View {
        HStack {
            Label {
                Text(title)
                    .font(.title3.bold())
                    .foregroundStyle(.primary)
            } icon: {
                Image(systemName: icon)
                    .foregroundStyle(Color.waffleSecondary)
            }
            Spacer()
            Menu {
                menu()
            } label: {
                Label("New", systemImage: "plus")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 12)
                    .frame(minHeight: 44)
                    .contentShape(Capsule())
            }
        }
        .textCase(nil)
    }

    // MARK: - Layouts

    private func layoutName(_ preset: Preset) -> String {
        preset.name.isEmpty ? String(localized: "Untitled Layout") : preset.name
    }

    private func layoutRow(_ preset: Preset) -> some View {
        let sites = LayoutNaming.hostSummary(urls: preset.urls, paneCount: preset.paneCount)
        return HStack(spacing: 4) {
            Button {
                applyPreset(preset)
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(layoutName(preset))
                        .font(.headline)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    if !sites.isEmpty {
                        Text(verbatim: sites)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    paneCountLabel(preset)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint(Text("Opens this layout"))

            Menu {
                Button { applyPreset(preset) } label: {
                    Label("Open Layout", systemImage: "arrow.right")
                }
                Button { onRename(preset) } label: {
                    Label("Rename", systemImage: "pencil")
                }
                Button { updatePreset(preset) } label: {
                    Label("Update with Open Panes", systemImage: "square.and.arrow.down")
                }
                ShareLink(
                    item: PresetShare.text(for: preset),
                    subject: Text(layoutName(preset))
                ) {
                    Label("Share Layout", systemImage: "square.and.arrow.up")
                }
                Button(role: .destructive) { onDeletePreset(preset) } label: {
                    Label("Delete", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.title3)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel(Text("Layout options"))
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) { onDeletePreset(preset) } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .swipeActions(edge: .leading, allowsFullSwipe: false) {
            Button { onRename(preset) } label: {
                Label("Rename", systemImage: "pencil")
            }
            .tint(.blue)
        }
    }

    private func paneCountLabel(_ preset: Preset) -> some View {
        let count = max(preset.paneCount, 1)
        return Label {
            if count == 1 {
                Text("1 pane")
            } else {
                Text("\(count) panes")
            }
        } icon: {
            Image(systemName: count == 1 ? "rectangle" : "rectangle.split.1x2")
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    private var emptyLayouts: some View {
        VStack(spacing: 10) {
            Image(systemName: "rectangle.split.2x1")
                .font(.system(size: 32, weight: .regular))
                .foregroundStyle(.secondary)
            Text("No saved layouts yet")
                .font(.headline)
            Text("Save your open panes as a layout to bring them all back with one tap.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, 16)
    }

    private var upsell: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("One Free Layout", systemImage: "drop.fill")
                .font(.headline)
                .tint(.waffleTertiary)
            Text("Your free layout is saved. Syrup lets you save as many as you like.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button("Get Syrup") { requestSyrup() }
                .buttonStyle(.wafflePrimary)
                .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 6)
    }

    // MARK: - Bookmarks

    private func bookmarkRow(_ bookmark: Bookmark) -> some View {
        Button {
            applyBookmark(bookmark)
        } label: {
            HStack {
                VStack(alignment: .leading) {
                    Text(bookmark.title.isEmpty ? bookmark.urlString : bookmark.title)
                        .bold()
                        .lineLimit(1)
                    Text(bookmark.urlString)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                Image(systemName: "arrow.turn.down.right")
                    .bold()
                    .foregroundStyle(Color.primary)
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(String(localized: "Open in Selected Pane")) { applyBookmark(bookmark) }
            Button(String(localized: "Edit")) { onEditBookmark(bookmark) }
            Button(role: .destructive) { onDeleteBookmark(bookmark) } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) { onDeleteBookmark(bookmark) } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .swipeActions(edge: .leading, allowsFullSwipe: false) {
            Button { onEditBookmark(bookmark) } label: {
                Label("Edit", systemImage: "pencil")
            }
            .tint(.blue)
        }
    }
}
#endif
