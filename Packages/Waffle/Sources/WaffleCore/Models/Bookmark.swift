//
//  Bookmark.swift
//  WaffleCore
//
//  A user-saved bookmark persisted with SwiftData. Stores the URL as a string for
//  portability and CloudKit friendliness. Defaults on all non-optional attributes and no
//  unique constraints, per CloudKit rules.
//

import Foundation
import SwiftData

@Model
public final class Bookmark {
    /// Stable identifier for the bookmark.
    public var id: UUID = UUID()
    /// The bookmark's URL as a string (persistence + CloudKit compatibility).
    public var urlString: String = ""
    /// Human-readable title shown in the UI.
    public var title: String = ""
    /// Timestamp of when the bookmark was created.
    public var createdAt: Date = Date.now
    /// User-defined order for drag-to-reorder in the UI (lower values appear first).
    public var sortIndex: Int = 0

    /// Creates a new bookmark from a URL and title.
    /// - Note: `sortIndex` defaults to 0; the repository assigns the real index on insert.
    public init(url: URL, title: String) {
        self.id = UUID()
        self.urlString = url.absoluteString
        self.title = title
        self.createdAt = .now
        self.sortIndex = 0
    }

    /// A convenience typed URL constructed from `urlString`, if valid.
    public var url: URL? { URL(string: urlString) }
}
