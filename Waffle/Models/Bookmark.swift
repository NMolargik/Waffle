//
//  Bookmark.swift
//  Waffle
//
//  Created by Nick Molargik on 9/2/25.
//

import Foundation
import SwiftData

/// A user-saved bookmark persisted with SwiftData.
///
/// This model stores a URL as a string for portability and CloudKit friendliness,
/// and includes a human-readable title and creation timestamp.
/// - Note: Defaults are provided for all non-optional attributes to align with
///   CloudKit constraints (no unique constraints).
@Model
final class Bookmark {
    /// Stable identifier for the bookmark.
    var id: UUID = UUID()
    /// The bookmark's URL as a string (used for persistence and CloudKit compatibility).
    var urlString: String = ""
    /// Human-readable title shown in the UI.
    var title: String = ""
    /// Timestamp of when the bookmark was created.
    var createdAt: Date = Date.now
    /// User-defined order for drag-to-reorder in the UI (lower values appear first).
    var sortIndex: Int = 0

    /// Creates a new bookmark from a URL and optional title.
    /// - Parameters:
    ///   - url: The URL to save.
    ///   - title: The display title to associate with the URL.
    /// - Note: sortIndex defaults to 0; callers should assign a desired index after insertion if needed.
    init(url: URL, title: String) {
        self.id = UUID()
        self.urlString = url.absoluteString
        self.title = title
        self.createdAt = .now
        self.sortIndex = 0
    }

    /// A convenience typed URL constructed from `urlString`, if valid.
    var url: URL? { URL(string: urlString) }
}

