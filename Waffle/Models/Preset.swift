//
//  Preset.swift
//  Waffle
//
//  Created by Nick Molargik on 9/2/25.
//

import Foundation
import SwiftData

/// A saved grid configuration (rows, columns, and URLs) persisted with SwiftData.
///
/// Presets capture the layout of the Waffle grid and the URLs assigned to each cell
/// so users can quickly restore a favorite configuration.
/// - Note: Defaults are provided for all non-optional attributes to align with
///   CloudKit constraints (no unique constraints).
@Model
final class Preset {
    /// Stable identifier for the preset.
    var id: UUID = UUID()
    /// Human-readable name shown in the UI.
    var name: String = ""
    /// Number of rows in the grid.
    var rows: Int = 1
    /// Number of columns in the grid.
    var cols: Int = 1
    /// Flattened list of URL strings in row-major order (length should equal rows * cols).
    var urls: [String] = []
    /// Timestamp of when the preset was created.
    var createdAt: Date = Date.now

    /// Creates a new preset with the given layout and URLs.
    /// - Parameters:
    ///   - name: Display name for the preset.
    ///   - rows: Number of rows in the grid.
    ///   - cols: Number of columns in the grid.
    ///   - urls: Row-major list of URL strings; expected count is `rows * cols`.
    init(name: String, rows: Int, cols: Int, urls: [String]) {
        self.id = UUID()
        self.name = name
        self.rows = rows
        self.cols = cols
        self.urls = urls
        self.createdAt = Date.now
    }
}
