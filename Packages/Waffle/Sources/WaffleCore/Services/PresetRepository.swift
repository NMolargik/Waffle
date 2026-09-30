//
//  PresetRepository.swift
//  WaffleCore
//
//  The preset data boundary, with single-verb use-case wrappers and typed failures.
//

import Foundation

@MainActor
public protocol PresetRepository: AnyObject {
    /// All presets, newest first.
    func presets() throws(PersistenceError) -> [Preset]

    /// The preset with `id`, if it still exists (deep links, intents).
    func preset(id: UUID) throws(PersistenceError) -> Preset?

    /// Inserts a new preset, defaulting the name to a timestamp when blank.
    @discardableResult
    func savePreset(named providedName: String?, rows: Int, cols: Int, urls: [String], now: Date) throws(PersistenceError) -> Preset

    /// Replaces an existing preset's layout with the current grid.
    func overwritePreset(_ preset: Preset, rows: Int, cols: Int, urls: [String]) throws(PersistenceError)

    /// Renames a preset; blank names are ignored.
    func renamePreset(_ preset: Preset, to name: String) throws(PersistenceError)

    /// Deletes a preset.
    func deletePreset(_ preset: Preset) throws(PersistenceError)

    /// Deletes every preset in one transaction.
    func deleteAllPresets() throws(PersistenceError)
}

// MARK: - Use cases

@MainActor
public protocol LoadPresets {
    func callAsFunction() throws(PersistenceError) -> [Preset]
}

public struct LoadPresetsUseCase: LoadPresets {
    private let repository: any PresetRepository
    public init(repository: any PresetRepository) { self.repository = repository }
    public func callAsFunction() throws(PersistenceError) -> [Preset] {
        try repository.presets()
    }
}

@MainActor
public protocol FindPreset {
    func callAsFunction(id: UUID) throws(PersistenceError) -> Preset?
}

public struct FindPresetUseCase: FindPreset {
    private let repository: any PresetRepository
    public init(repository: any PresetRepository) { self.repository = repository }
    public func callAsFunction(id: UUID) throws(PersistenceError) -> Preset? {
        try repository.preset(id: id)
    }
}

@MainActor
public protocol SavePreset {
    @discardableResult
    func callAsFunction(named name: String?, rows: Int, cols: Int, urls: [String], now: Date) throws(PersistenceError) -> Preset
}

public extension SavePreset {
    @discardableResult
    func callAsFunction(named name: String?, rows: Int, cols: Int, urls: [String]) throws(PersistenceError) -> Preset {
        try callAsFunction(named: name, rows: rows, cols: cols, urls: urls, now: .now)
    }
}

public struct SavePresetUseCase: SavePreset {
    private let repository: any PresetRepository
    public init(repository: any PresetRepository) { self.repository = repository }
    @discardableResult
    public func callAsFunction(named name: String?, rows: Int, cols: Int, urls: [String], now: Date) throws(PersistenceError) -> Preset {
        try repository.savePreset(named: name, rows: rows, cols: cols, urls: urls, now: now)
    }
}

@MainActor
public protocol OverwritePreset {
    func callAsFunction(_ preset: Preset, rows: Int, cols: Int, urls: [String]) throws(PersistenceError)
}

public struct OverwritePresetUseCase: OverwritePreset {
    private let repository: any PresetRepository
    public init(repository: any PresetRepository) { self.repository = repository }
    public func callAsFunction(_ preset: Preset, rows: Int, cols: Int, urls: [String]) throws(PersistenceError) {
        try repository.overwritePreset(preset, rows: rows, cols: cols, urls: urls)
    }
}

@MainActor
public protocol RenamePreset {
    func callAsFunction(_ preset: Preset, to name: String) throws(PersistenceError)
}

public struct RenamePresetUseCase: RenamePreset {
    private let repository: any PresetRepository
    public init(repository: any PresetRepository) { self.repository = repository }
    public func callAsFunction(_ preset: Preset, to name: String) throws(PersistenceError) {
        try repository.renamePreset(preset, to: name)
    }
}

@MainActor
public protocol DeletePreset {
    func callAsFunction(_ preset: Preset) throws(PersistenceError)
}

public struct DeletePresetUseCase: DeletePreset {
    private let repository: any PresetRepository
    public init(repository: any PresetRepository) { self.repository = repository }
    public func callAsFunction(_ preset: Preset) throws(PersistenceError) {
        try repository.deletePreset(preset)
    }
}

@MainActor
public protocol DeleteAllPresets {
    func callAsFunction() throws(PersistenceError)
}

public struct DeleteAllPresetsUseCase: DeleteAllPresets {
    private let repository: any PresetRepository
    public init(repository: any PresetRepository) { self.repository = repository }
    public func callAsFunction() throws(PersistenceError) {
        try repository.deleteAllPresets()
    }
}
