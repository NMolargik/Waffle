//
//  SpotlightIndexing.swift
//  Waffle
//
//  Seam over CoreSpotlight semantic indexing so library changes can be
//  verified in tests without touching the real index.
//

import AppIntents
import CoreSpotlight
import Foundation
import os

/// Abstraction over Spotlight's app-entity index.
protocol SpotlightIndexing {
    func reindex(presets: [PresetEntity], bookmarks: [BookmarkEntity])
}

/// Production conformance backed by `CSSearchableIndex`, giving Spotlight
/// semantic search over presets and bookmarks via IndexedEntity.
struct CoreSpotlightIndexer: SpotlightIndexing {
    nonisolated init() {}

    func reindex(presets: [PresetEntity], bookmarks: [BookmarkEntity]) {
        Task.detached(priority: .utility) {
            let index = CSSearchableIndex.default()
            do {
                try await index.deleteAppEntities(ofType: PresetEntity.self)
                try await index.deleteAppEntities(ofType: BookmarkEntity.self)
                try await index.indexAppEntities(presets)
                try await index.indexAppEntities(bookmarks)
            } catch {
                Log.spotlight.error("Spotlight reindex failed: \(error.localizedDescription)")
            }
        }
    }
}
