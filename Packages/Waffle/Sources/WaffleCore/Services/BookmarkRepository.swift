//
//  BookmarkRepository.swift
//  WaffleCore
//
//  The bookmark data boundary. `DefaultBookmarkRepository` in `WaffleData` owns the
//  SwiftData context, assigns/normalizes `sortIndex`, and notifies the library change
//  stream. Each operation gets a thin single-verb use-case wrapper so view models depend
//  on one verb, not the whole repository. Failures are typed (`throws(PersistenceError)`).
//

import Foundation

@MainActor
public protocol BookmarkRepository: AnyObject {
    /// All bookmarks, ordered by `sortIndex` then newest-created first.
    func bookmarks() throws(PersistenceError) -> [Bookmark]

    /// The bookmark with `id`, if it still exists (deep links, intents).
    func bookmark(id: UUID) throws(PersistenceError) -> Bookmark?

    /// Validates and inserts a new bookmark at the end of the sort order.
    /// Returns nil (without persisting) when `urlString` is empty or invalid.
    @discardableResult
    func addBookmark(urlString: String, title: String?) throws(PersistenceError) -> Bookmark?

    /// Persists edits to an existing bookmark.
    func updateBookmark(_ bookmark: Bookmark, title: String, urlString: String) throws(PersistenceError)

    /// Deletes a bookmark and renumbers the remaining sort indexes.
    func deleteBookmark(_ bookmark: Bookmark) throws(PersistenceError)

    /// Applies a drag-to-reorder move and renumbers `sortIndex` to match.
    func moveBookmarks(_ ordered: [Bookmark], from source: IndexSet, to destination: Int) throws(PersistenceError)

    /// Deletes every bookmark in one transaction.
    func deleteAllBookmarks() throws(PersistenceError)

    /// Repairs legacy data where bookmarks share duplicate sort indexes.
    func normalizeBookmarkSortIndexes() throws(PersistenceError)
}

// MARK: - Use cases

@MainActor
public protocol LoadBookmarks {
    func callAsFunction() throws(PersistenceError) -> [Bookmark]
}

public struct LoadBookmarksUseCase: LoadBookmarks {
    private let repository: any BookmarkRepository
    public init(repository: any BookmarkRepository) { self.repository = repository }
    public func callAsFunction() throws(PersistenceError) -> [Bookmark] {
        try repository.bookmarks()
    }
}

@MainActor
public protocol FindBookmark {
    func callAsFunction(id: UUID) throws(PersistenceError) -> Bookmark?
}

public struct FindBookmarkUseCase: FindBookmark {
    private let repository: any BookmarkRepository
    public init(repository: any BookmarkRepository) { self.repository = repository }
    public func callAsFunction(id: UUID) throws(PersistenceError) -> Bookmark? {
        try repository.bookmark(id: id)
    }
}

@MainActor
public protocol AddBookmark {
    /// Returns nil when the input isn't a bookmarkable URL (nothing persisted).
    @discardableResult
    func callAsFunction(urlString: String, title: String?) throws(PersistenceError) -> Bookmark?
}

public struct AddBookmarkUseCase: AddBookmark {
    private let repository: any BookmarkRepository
    public init(repository: any BookmarkRepository) { self.repository = repository }
    @discardableResult
    public func callAsFunction(urlString: String, title: String?) throws(PersistenceError) -> Bookmark? {
        try repository.addBookmark(urlString: urlString, title: title)
    }
}

@MainActor
public protocol UpdateBookmark {
    func callAsFunction(_ bookmark: Bookmark, title: String, urlString: String) throws(PersistenceError)
}

public struct UpdateBookmarkUseCase: UpdateBookmark {
    private let repository: any BookmarkRepository
    public init(repository: any BookmarkRepository) { self.repository = repository }
    public func callAsFunction(_ bookmark: Bookmark, title: String, urlString: String) throws(PersistenceError) {
        try repository.updateBookmark(bookmark, title: title, urlString: urlString)
    }
}

@MainActor
public protocol DeleteBookmark {
    func callAsFunction(_ bookmark: Bookmark) throws(PersistenceError)
}

public struct DeleteBookmarkUseCase: DeleteBookmark {
    private let repository: any BookmarkRepository
    public init(repository: any BookmarkRepository) { self.repository = repository }
    public func callAsFunction(_ bookmark: Bookmark) throws(PersistenceError) {
        try repository.deleteBookmark(bookmark)
    }
}

@MainActor
public protocol MoveBookmarks {
    func callAsFunction(_ ordered: [Bookmark], from source: IndexSet, to destination: Int) throws(PersistenceError)
}

public struct MoveBookmarksUseCase: MoveBookmarks {
    private let repository: any BookmarkRepository
    public init(repository: any BookmarkRepository) { self.repository = repository }
    public func callAsFunction(_ ordered: [Bookmark], from source: IndexSet, to destination: Int) throws(PersistenceError) {
        try repository.moveBookmarks(ordered, from: source, to: destination)
    }
}

@MainActor
public protocol DeleteAllBookmarks {
    func callAsFunction() throws(PersistenceError)
}

public struct DeleteAllBookmarksUseCase: DeleteAllBookmarks {
    private let repository: any BookmarkRepository
    public init(repository: any BookmarkRepository) { self.repository = repository }
    public func callAsFunction() throws(PersistenceError) {
        try repository.deleteAllBookmarks()
    }
}

@MainActor
public protocol NormalizeBookmarkOrder {
    func callAsFunction() throws(PersistenceError)
}

public struct NormalizeBookmarkOrderUseCase: NormalizeBookmarkOrder {
    private let repository: any BookmarkRepository
    public init(repository: any BookmarkRepository) { self.repository = repository }
    public func callAsFunction() throws(PersistenceError) {
        try repository.normalizeBookmarkSortIndexes()
    }
}
