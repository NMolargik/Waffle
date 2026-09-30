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

    public init(rows: Int, cols: Int, urls: [String], selectedIndex: Int?) {
        self.rows = rows
        self.cols = cols
        self.urls = urls
        self.selectedIndex = selectedIndex
    }
}
