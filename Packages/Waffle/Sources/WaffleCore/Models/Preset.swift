//
//  Preset.swift
//  WaffleCore
//
//  A saved grid configuration (rows, columns, and URLs) persisted with SwiftData, so
//  users can quickly restore a favorite layout. CloudKit rules: defaults on all
//  non-optional attributes, no unique constraints.
//

import Foundation
import SwiftData

@Model
public final class Preset {
    /// Stable identifier for the preset.
    public var id: UUID = UUID()
    /// Human-readable name shown in the UI.
    public var name: String = ""
    /// Number of rows in the grid.
    public var rows: Int = 1
    /// Number of columns in the grid.
    public var cols: Int = 1
    /// Flattened list of URL strings in row-major order (length should equal rows * cols).
    public var urls: [String] = []
    /// Timestamp of when the preset was created.
    public var createdAt: Date = Date.now

    /// Creates a new preset with the given layout and URLs (row-major, `rows * cols`).
    public init(name: String, rows: Int, cols: Int, urls: [String]) {
        self.id = UUID()
        self.name = name
        self.rows = rows
        self.cols = cols
        self.urls = urls
        self.createdAt = Date.now
    }
}
