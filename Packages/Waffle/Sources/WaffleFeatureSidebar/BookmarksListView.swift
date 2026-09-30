//
//  BookmarksListView.swift
//  WaffleFeatureSidebar
//

#if os(iOS)
import SwiftUI
import WaffleCore

struct BookmarksListView: View {
    var bookmarks: [Bookmark]
    var applyBookmark: (Bookmark) -> Void
    var onEdit: (Bookmark) -> Void
    var onDelete: (Bookmark) -> Void
    var onMove: ((IndexSet, Int) -> Void)?

    var body: some View {
        List {
            if bookmarks.isEmpty {
                Section {
                    VStack(spacing: 10) {
                        Image(systemName: "bookmark.slash")
                            .font(.system(size: 32, weight: .regular))
                            .foregroundStyle(.secondary)
                        Text("No bookmarks yet")
                            .font(.headline)
                        Text("Save your favorite sites to find them fast.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 24)
                    .listRowInsets(EdgeInsets(top: 16, leading: 12, bottom: 16, trailing: 12))
                } header: {
                    Color.clear.frame(height: 0.1)
                }
            } else {
                ForEach(bookmarks) { bm in
                    Button {
                        applyBookmark(bm)
                    } label: {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(bm.title.isEmpty ? bm.urlString : bm.title)
                                    .bold()
                                    .lineLimit(1)
                                Text(bm.urlString)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            Spacer()
                            Image(systemName: "arrow.turn.down.right")
                                .bold()
                                .foregroundStyle(Color.primary)
                        }
                    }
                    .buttonStyle(.plain)
                    .draggable(bm.url ?? URL(string: "https://apple.com")!)
                    .contextMenu {
                        Button(String(localized: "Apply to cell")) { applyBookmark(bm) }
                        Button(String(localized: "Edit")) { onEdit(bm) }
                        Button(role: .destructive) {
                            onDelete(bm)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            onDelete(bm)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
                .onMove { from, to in
                    onMove?(from, to)
                }
                .moveDisabled(onMove == nil)
            }
        }
    }
}
#endif
