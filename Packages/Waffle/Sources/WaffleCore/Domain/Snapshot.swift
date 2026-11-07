//
//  Snapshot.swift
//  WaffleCore
//
//  The persisted shape of the grid: dimensions, row-major URLs, and selection.
//  (Previously nested in WaffleState; top-level now so the pure domain owns it.)
//

import Foundation

nonisolated public struct Snapshot: Codable, Equatable, Sendable {
    public let rows: Int
    public let cols: Int
    public let urls: [String]
    public let selectedIndex: Int?
    /// Per-cell auto-refresh periods in seconds (row-major; 0 or missing = off).
    public let refreshIntervals: [Int]
    /// Per-cell content-blocking overrides (`ContentBlockingMode` raw values, row-major;
    /// missing = follow the global setting).
    public let contentBlockingModes: [Int]

    public init(rows: Int, cols: Int, urls: [String], selectedIndex: Int?, refreshIntervals: [Int] = [], contentBlockingModes: [Int] = []) {
        self.rows = rows
        self.cols = cols
        self.urls = urls
        self.selectedIndex = selectedIndex
        self.refreshIntervals = refreshIntervals
        self.contentBlockingModes = contentBlockingModes
    }

    private enum CodingKeys: String, CodingKey {
        case rows, cols, urls, selectedIndex, refreshIntervals, contentBlockingModes
    }

    /// Snapshots written before 1.5.0 have no `refreshIntervals`; decode them as all-off.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        rows = try container.decode(Int.self, forKey: .rows)
        cols = try container.decode(Int.self, forKey: .cols)
        urls = try container.decode([String].self, forKey: .urls)
        selectedIndex = try container.decodeIfPresent(Int.self, forKey: .selectedIndex)
        refreshIntervals = try container.decodeIfPresent([Int].self, forKey: .refreshIntervals) ?? []
        contentBlockingModes = try container.decodeIfPresent([Int].self, forKey: .contentBlockingModes) ?? []
    }
}
