//
//  BookmarksListView.swift
//  Waffle
//
//  Created by Nick Molargik on 9/3/25.
//

import SwiftUI

struct BookmarksListView: View {
    var bookmarks: [Bookmark]
    var applyBookmark: (Bookmark) -> Void
    var onEdit: (Bookmark) -> Void
    var onDelete: (Bookmark) -> Void
    
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
                    // Keep default section spacing without showing a visible header
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
                    .contextMenu {
                        Button("Apply") { applyBookmark(bm) }
                        Button("Edit") { onEdit(bm) }
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
            }
        }
    }
}


#Preview {
    let mocks: [Bookmark] = [
        Bookmark(url: URL(string: "https://apple.com")!, title: "Apple"),
        Bookmark(url: URL(string: "https://developer.apple.com/documentation")!, title: "Documentation"),
        Bookmark(url: URL(string: "https://news.ycombinator.com")!, title: "Hacker News"),
        Bookmark(url: URL(string: "https://github.com")!, title: "GitHub"),
        // Long title
        Bookmark(url: URL(string: "https://www.raywenderlich.com")!, title: "Massive Guide to SwiftUI Layout Techniques and Best Practices"),
        {
            let bm = Bookmark(url: URL(string: "https://www.example.com/this/is/a/very/long/path/that/tests/truncation?with=query&and=params=1")!, title: "")
            return bm
        }(),
    ]

    return BookmarksListView(
        bookmarks: mocks,
        applyBookmark: { bm in print("[Preview] Apply:", bm.title.isEmpty ? bm.urlString : bm.title) },
        onEdit: { bm in print("[Preview] Edit:", bm.title.isEmpty ? bm.urlString : bm.title) },
        onDelete: { bm in print("[Preview] Delete:", bm.title.isEmpty ? bm.urlString : bm.title) }
    )
    .padding()
}

