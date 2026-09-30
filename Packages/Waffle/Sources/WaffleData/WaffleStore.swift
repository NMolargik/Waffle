//
//  WaffleStore.swift
//  WaffleData
//
//  Builds the SwiftData container with graceful degradation: CloudKit-synced → local-only
//  → in-memory. CloudKit being unavailable (no account, no network at first launch) must
//  never take the app down.
//

import Foundation
import SwiftData
import WaffleCore
import os

public enum WaffleStore {
    /// The CloudKit container backing the private database.
    public static let cloudKitContainerID = "iCloud.com.molargiksoftware.Waffle"

    /// Builds the shared container. Pass `inMemory: true` for tests/previews.
    public static func makeContainer(inMemory: Bool = false) -> ModelContainer {
        let schema = Schema([Bookmark.self, Preset.self])

        if inMemory {
            do {
                let memory = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
                return try ModelContainer(for: schema, configurations: memory)
            } catch {
                fatalError("Failed to create an in-memory ModelContainer: \(error)")
            }
        }

        do {
            let cloud = ModelConfiguration(
                cloudKitContainerID,
                schema: schema,
                cloudKitDatabase: .private(cloudKitContainerID)
            )
            return try ModelContainer(for: schema, configurations: cloud)
        } catch {
            Log.app.error("CloudKit container unavailable, falling back to local store: \(error.localizedDescription)")
        }

        do {
            let local = ModelConfiguration(schema: schema, cloudKitDatabase: .none)
            return try ModelContainer(for: schema, configurations: local)
        } catch {
            Log.app.fault("Local store unavailable, falling back to in-memory: \(error.localizedDescription)")
        }

        do {
            let memory = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            return try ModelContainer(for: schema, configurations: memory)
        } catch {
            fatalError("Failed to create even an in-memory ModelContainer: \(error)")
        }
    }
}
