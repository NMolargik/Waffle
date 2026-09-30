//
//  DefaultBookmarkRepository.swift
//  WaffleData
//
//  The SwiftData-backed `BookmarkRepository`. Owns sort-index assignment and
//  normalization, throws typed failures (no presentation coupling — view models surface
//  errors), and notifies the library change stream after every successful mutation.
//

import Foundation
import SwiftData
import WaffleCore
import os

@MainActor
public final class DefaultBookmarkRepository: BookmarkRepository {

    /// Retained on purpose: a `ModelContext` does not keep its container alive.
    private let container: ModelContainer
    private let changeCenter: LibraryChangeCenter?

    private var context: ModelContext { container.mainContext }

    public init(container: ModelContainer, changeCenter: LibraryChangeCenter? = nil) {
        self.container = container
        self.changeCenter = changeCenter
    }

    // MARK: - Reading

    public func bookmarks() throws(PersistenceError) -> [Bookmark] {
        let descriptor = FetchDescriptor<Bookmark>(sortBy: [
            SortDescriptor(\.sortIndex, order: .forward),
            SortDescriptor(\.createdAt, order: .reverse),
        ])
        do {
            return try context.fetch(descriptor)
        } catch {
            Log.library.error("Bookmark fetch failed: \(error.localizedDescription)")
            throw .fetchFailed(error.localizedDescription)
        }
    }

    public func bookmark(id: UUID) throws(PersistenceError) -> Bookmark? {
        var descriptor = FetchDescriptor<Bookmark>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        do {
            return try context.fetch(descriptor).first
        } catch {
            Log.library.error("Bookmark lookup failed: \(error.localizedDescription)")
            throw .fetchFailed(error.localizedDescription)
        }
    }

    // MARK: - Writing

    @discardableResult
    public func addBookmark(urlString: String, title: String?) throws(PersistenceError) -> Bookmark? {
        let trimmedURL = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedURL.isEmpty, let url = URL(string: trimmedURL) else {
            return nil   // Not persistable input — the caller decides how to tell the user.
        }

        let trimmedTitle = title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let bookmark = Bookmark(url: url, title: trimmedTitle.isEmpty ? trimmedURL : trimmedTitle)
        bookmark.sortIndex = ((try bookmarks()).map(\.sortIndex).max() ?? -1) + 1
        context.insert(bookmark)
        try save(operation: "add bookmark")
        return bookmark
    }

    public func updateBookmark(_ bookmark: Bookmark, title: String, urlString: String) throws(PersistenceError) {
        bookmark.title = title
        bookmark.urlString = urlString
        try save(operation: "update bookmark")
    }

    public func deleteBookmark(_ bookmark: Bookmark) throws(PersistenceError) {
        context.delete(bookmark)
        try normalizeSortIndexes(persist: false)
        try save(operation: "delete bookmark")
    }

    public func moveBookmarks(_ ordered: [Bookmark], from source: IndexSet, to destination: Int) throws(PersistenceError) {
        let reordered = GridLayout.moved(ordered, fromOffsets: source, toOffset: destination)
        for (index, bookmark) in reordered.enumerated() where bookmark.sortIndex != index {
            bookmark.sortIndex = index
        }
        try save(operation: "reorder bookmarks")
    }

    public func deleteAllBookmarks() throws(PersistenceError) {
        do {
            let all = try context.fetch(FetchDescriptor<Bookmark>())
            all.forEach { context.delete($0) }
        } catch {
            Log.library.error("Bookmark fetch for delete-all failed: \(error.localizedDescription)")
            throw PersistenceError.fetchFailed(error.localizedDescription)
        }
        try save(operation: "delete all bookmarks")
    }

    public func normalizeBookmarkSortIndexes() throws(PersistenceError) {
        try normalizeSortIndexes(persist: true)
    }

    /// Repairs legacy data where every bookmark shares sortIndex 0.
    private func normalizeSortIndexes(persist: Bool) throws(PersistenceError) {
        var changed = false
        for (index, bookmark) in (try bookmarks()).enumerated() where bookmark.sortIndex != index {
            bookmark.sortIndex = index
            changed = true
        }
        if persist, changed {
            try save(operation: "normalize bookmark order")
        }
    }

    // MARK: - Saving

    private func save(operation: String) throws(PersistenceError) {
        do {
            try context.save()
        } catch {
            Log.library.error("Failed to \(operation): \(error.localizedDescription)")
            throw .saveFailed(error.localizedDescription)
        }
        changeCenter?.notify()
    }
}
