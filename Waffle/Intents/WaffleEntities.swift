//
//  WaffleEntities.swift
//  Waffle
//
//  App Intents entities for presets and bookmarks, indexed into Spotlight
//  for semantic search and Siri.
//

import AppIntents
import CoreSpotlight
import Foundation

// MARK: - Preset

struct PresetEntity: AppEntity, IndexedEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(
        name: "Grid Preset",
        numericFormat: "\(placeholder: .int) grid presets"
    )
    static let defaultQuery = PresetEntityQuery()

    let id: UUID
    var name: String
    var rows: Int
    var cols: Int

    @MainActor
    init(preset: Preset) {
        self.id = preset.id
        self.name = preset.name.isEmpty ? String(localized: "Untitled Preset") : preset.name
        self.rows = preset.rows
        self.cols = preset.cols
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(name)",
            subtitle: "\(rows)×\(cols) waffle grid",
            image: .init(systemName: "square.grid.3x3.fill")
        )
    }

    var attributeSet: CSSearchableItemAttributeSet {
        let attributes = CSSearchableItemAttributeSet(contentType: .content)
        attributes.title = name
        attributes.contentDescription = String(localized: "A \(rows)×\(cols) waffle grid layout")
        attributes.keywords = [name, "grid", "preset", "waffle", "browser layout"]
        return attributes
    }
}

struct PresetEntityQuery: EntityQuery {
    @Dependency private var library: LibraryManager

    func entities(for identifiers: [UUID]) async throws -> [PresetEntity] {
        await MainActor.run {
            identifiers.compactMap { id in
                library.preset(id: id).map(PresetEntity.init)
            }
        }
    }

    func suggestedEntities() async throws -> [PresetEntity] {
        await MainActor.run {
            library.presets().map(PresetEntity.init)
        }
    }
}

// MARK: - Bookmark

struct BookmarkEntity: AppEntity, IndexedEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(
        name: "Bookmark",
        numericFormat: "\(placeholder: .int) bookmarks"
    )
    static let defaultQuery = BookmarkEntityQuery()

    let id: UUID
    var title: String
    var urlString: String

    @MainActor
    init(bookmark: Bookmark) {
        self.id = bookmark.id
        self.title = bookmark.title.isEmpty ? bookmark.urlString : bookmark.title
        self.urlString = bookmark.urlString
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(title)",
            subtitle: "\(URLDisplayFormatter.compact(urlString))",
            image: .init(systemName: "bookmark.fill")
        )
    }

    var attributeSet: CSSearchableItemAttributeSet {
        let attributes = CSSearchableItemAttributeSet(contentType: .url)
        attributes.title = title
        attributes.contentDescription = urlString
        attributes.contentURL = URL(string: urlString)
        attributes.keywords = [title, "bookmark", "waffle", URLDisplayFormatter.compact(urlString)]
        return attributes
    }
}

struct BookmarkEntityQuery: EntityQuery {
    @Dependency private var library: LibraryManager

    func entities(for identifiers: [UUID]) async throws -> [BookmarkEntity] {
        await MainActor.run {
            identifiers.compactMap { id in
                library.bookmark(id: id).map(BookmarkEntity.init)
            }
        }
    }

    func suggestedEntities() async throws -> [BookmarkEntity] {
        await MainActor.run {
            library.bookmarks().map(BookmarkEntity.init)
        }
    }
}
