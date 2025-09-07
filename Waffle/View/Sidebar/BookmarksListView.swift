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
    var onMove: (IndexSet, Int) -> Void
    
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
                .onMove(perform: onMove)
            }
        }
    }
}


#Preview {
    let mocks: [Bookmark] = [
        {
            let bm = Bookmark(url: URL(string: "https://apple.com")!, title: "Apple")
            bm.sortIndex = 0
            return bm
        }(),
        {
            let bm = Bookmark(url: URL(string: "https://developer.apple.com/documentation")!, title: "Documentation")
            bm.sortIndex = 1
            return bm
        }(),
        {
            let bm = Bookmark(url: URL(string: "https://news.ycombinator.com")!, title: "Hacker News")
            bm.sortIndex = 2
            return bm
        }(),
        {
            let bm = Bookmark(url: URL(string: "https://github.com")!, title: "GitHub")
            bm.sortIndex = 3
            return bm
        }(),
        {
            let bm = Bookmark(url: URL(string: "https://www.raywenderlich.com")!, title: "Massive Guide to SwiftUI Layout Techniques and Best Practices")
            bm.sortIndex = 4
            return bm
        }(),
        {
            let bm = Bookmark(url: URL(string: "https://www.example.com/this/is/a/very/long/path/that/tests/truncation?with=query&and=params=1")!, title: "")
            bm.sortIndex = 5
            return bm
        }(),
    ]

    return BookmarksListView(
        bookmarks: mocks.sorted(by: { $0.sortIndex < $1.sortIndex }),
        applyBookmark: { bm in print("[Preview] Apply:", bm.title.isEmpty ? bm.urlString : bm.title) },
        onEdit: { bm in print("[Preview] Edit:", bm.title.isEmpty ? bm.urlString : bm.title) },
        onDelete: { bm in print("[Preview] Delete:", bm.title.isEmpty ? bm.urlString : bm.title) },
        onMove: { from, to in
            var arr = mocks
            arr.move(fromOffsets: from, toOffset: to)
            for (idx, b) in arr.enumerated() { b.sortIndex = idx }
            print("[Preview] New order:", arr.map { $0.title.isEmpty ? $0.urlString : $0.title })
        }
    )
    .padding()
}

