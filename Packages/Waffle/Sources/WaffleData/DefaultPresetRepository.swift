//
//  DefaultPresetRepository.swift
//  WaffleData
//
//  The SwiftData-backed `PresetRepository`: typed failures, change-stream notification.
//

import Foundation
import SwiftData
import WaffleCore
import os

@MainActor
public final class DefaultPresetRepository: PresetRepository {

    /// Retained on purpose: a `ModelContext` does not keep its container alive.
    private let container: ModelContainer
    private let changeCenter: LibraryChangeCenter?

    private var context: ModelContext { container.mainContext }

    public init(container: ModelContainer, changeCenter: LibraryChangeCenter? = nil) {
        self.container = container
        self.changeCenter = changeCenter
    }

    // MARK: - Reading

    public func presets() throws(PersistenceError) -> [Preset] {
        let descriptor = FetchDescriptor<Preset>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        do {
            return try context.fetch(descriptor)
        } catch {
            Log.library.error("Preset fetch failed: \(error.localizedDescription)")
            throw .fetchFailed(error.localizedDescription)
        }
    }

    public func preset(id: UUID) throws(PersistenceError) -> Preset? {
        var descriptor = FetchDescriptor<Preset>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        do {
            return try context.fetch(descriptor).first
        } catch {
            Log.library.error("Preset lookup failed: \(error.localizedDescription)")
            throw .fetchFailed(error.localizedDescription)
        }
    }

    // MARK: - Writing

    @discardableResult
    public func savePreset(named providedName: String?, rows: Int, cols: Int, urls: [String], now: Date) throws(PersistenceError) -> Preset {
        let name: String = {
            if let providedName, !providedName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return providedName
            }
            return String(localized: "Preset \(now.formatted(date: .numeric, time: .shortened))")
        }()
        let preset = Preset(name: name, rows: rows, cols: cols, urls: urls)
        context.insert(preset)
        try save(operation: "save preset")
        return preset
    }

    public func overwritePreset(_ preset: Preset, rows: Int, cols: Int, urls: [String]) throws(PersistenceError) {
        preset.rows = max(1, rows)
        preset.cols = max(1, cols)
        preset.urls = urls
        try save(operation: "overwrite preset")
    }

    public func renamePreset(_ preset: Preset, to name: String) throws(PersistenceError) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        preset.name = trimmed
        try save(operation: "rename preset")
    }

    public func deletePreset(_ preset: Preset) throws(PersistenceError) {
        context.delete(preset)
        try save(operation: "delete preset")
    }

    public func deleteAllPresets() throws(PersistenceError) {
        do {
            let all = try context.fetch(FetchDescriptor<Preset>())
            all.forEach { context.delete($0) }
        } catch {
            Log.library.error("Preset fetch for delete-all failed: \(error.localizedDescription)")
            throw PersistenceError.fetchFailed(error.localizedDescription)
        }
        try save(operation: "delete all presets")
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
