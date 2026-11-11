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
    /// Per-cell auto-refresh periods in seconds, row-major (0 or missing = off). Empty for
    /// presets saved before 1.5.0.
    public var refreshIntervals: [Int] = []
    /// Number of panes when saved from iPhone or iPhone Duo (0 = an iPad grid preset). The
    /// URLs are still row-major in `urls`, so iPads open the same layout as a small grid.
    public var paneCount: Int = 0
    /// `PaneRatios.array` (`[primary, stackA, stackB]`) for pane layouts; empty = even splits.
    public var paneRatios: [Double] = []

    /// Creates a new preset with the given layout and URLs (row-major, `rows * cols`).
    public init(name: String, rows: Int, cols: Int, urls: [String], refreshIntervals: [Int] = [], paneCount: Int = 0, paneRatios: [Double] = []) {
        self.id = UUID()
        self.name = name
        self.rows = rows
        self.cols = cols
        self.urls = urls
        self.refreshIntervals = refreshIntervals
        self.paneCount = paneCount
        self.paneRatios = paneRatios
        self.createdAt = Date.now
    }
}
