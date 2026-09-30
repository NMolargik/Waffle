//
//  SeamImplementations.swift
//  Waffle
//
//  App-target conformances for the package seams that need AppIntents entity types:
//  Spotlight indexing, Siri preset donation, and browsing-activity annotation.
//

import AppIntents
import CoreSpotlight
import Foundation
import WaffleCore
import os

/// Keeps Spotlight's semantic index in sync with the library, giving Spotlight
/// search over presets and bookmarks via IndexedEntity.
struct CoreSpotlightIndexer: LibraryIndexing {
    nonisolated init() {}

    func reindex(presets: [Preset], bookmarks: [Bookmark]) {
        // Map models to Sendable entity values on the MainActor, then hand off.
        let presetEntities = presets.map(PresetEntity.init)
        let bookmarkEntities = bookmarks.map(BookmarkEntity.init)
        Task.detached(priority: .utility) {
            let index = CSSearchableIndex.default()
            do {
                try await index.deleteAppEntities(ofType: PresetEntity.self)
                try await index.deleteAppEntities(ofType: BookmarkEntity.self)
                try await index.indexAppEntities(presetEntities)
                try await index.indexAppEntities(bookmarkEntities)
            } catch {
                Log.spotlight.error("Spotlight reindex failed: \(error.localizedDescription)")
            }
        }
    }
}

/// Donates the matching intent so Siri learns which presets the user reaches for
/// and can suggest them proactively.
struct WafflePresetDonator: PresetDonating {
    nonisolated init() {}

    func donateOpenPreset(_ preset: Preset) {
        let intent = OpenPresetIntent()
        intent.preset = PresetEntity(preset: preset)
        intent.donate()
    }
}

/// Tags the Handoff/Spotlight browsing activity with the bookmark's app-entity
/// identifier so Siri's on-screen awareness can resolve the page.
struct BrowsingActivityAnnotator: BrowsingActivityAnnotating {
    nonisolated init() {}

    func annotate(_ activity: NSUserActivity, matching bookmark: Bookmark) {
        activity.appEntityIdentifier = EntityIdentifier(for: BookmarkEntity.self, identifier: bookmark.id)
    }
}
