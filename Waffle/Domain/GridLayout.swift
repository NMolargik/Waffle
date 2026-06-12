//
//  GridLayout.swift
//  Waffle
//
//  Pure grid math shared by WaffleState, presets, snapshots, and the rearrange UI.
//

import Foundation

/// Pure, deterministic helpers for working with the row-major waffle grid.
nonisolated enum GridLayout {
    /// Resizes a 2D grid to `rows` x `cols`, preserving existing elements and
    /// creating new ones with `makeElement` where the grid grows.
    static func resized<Element>(
        _ grid: [[Element]],
        rows: Int,
        cols: Int,
        makeElement: () -> Element
    ) -> [[Element]] {
        let targetRows = max(1, rows)
        let targetCols = max(1, cols)

        var result = grid
        // Trim or grow rows.
        if result.count > targetRows {
            result.removeLast(result.count - targetRows)
        }
        // Trim or grow columns on surviving rows.
        for index in result.indices {
            if result[index].count > targetCols {
                result[index].removeLast(result[index].count - targetCols)
            } else {
                while result[index].count < targetCols {
                    result[index].append(makeElement())
                }
            }
        }
        while result.count < targetRows {
            result.append((0..<targetCols).map { _ in makeElement() })
        }
        return result
    }

    /// Row-major flat index for a grid position.
    static func index(row: Int, column: Int, columnCount: Int) -> Int {
        row * max(1, columnCount) + column
    }

    /// Grid position for a row-major flat index.
    static func position(of index: Int, columnCount: Int) -> (row: Int, column: Int) {
        let cols = max(1, columnCount)
        return (index / cols, index % cols)
    }

    /// Lays out a flat URL list into a rows x cols grid, padding missing slots
    /// with `fill` and dropping extras.
    static func rowMajorURLs(_ urls: [String], rows: Int, cols: Int, fill: String) -> [[String]] {
        let targetRows = max(1, rows)
        let targetCols = max(1, cols)
        return (0..<targetRows).map { row in
            (0..<targetCols).map { col in
                let flat = index(row: row, column: col, columnCount: targetCols)
                return flat < urls.count ? urls[flat] : fill
            }
        }
    }

    /// Pure equivalent of SwiftUI's `move(fromOffsets:toOffset:)` so managers
    /// don't need a SwiftUI dependency.
    static func moved<Element>(_ array: [Element], fromOffsets source: IndexSet, toOffset destination: Int) -> [Element] {
        let sourceIndices = source.filter { $0 >= 0 && $0 < array.count }.sorted()
        guard !sourceIndices.isEmpty else { return array }

        let moving = sourceIndices.map { array[$0] }
        var remaining = array
        for index in sourceIndices.reversed() {
            remaining.remove(at: index)
        }

        // Shift the destination left for every removed element before it.
        let adjustedDestination = destination - sourceIndices.filter { $0 < destination }.count
        let insertionIndex = min(max(0, adjustedDestination), remaining.count)
        remaining.insert(contentsOf: moving, at: insertionIndex)
        return remaining
    }

    /// Clamps a requested grid size into [1, max] on both axes.
    static func clamped(rows: Int, cols: Int, maxRows: Int, maxCols: Int) -> (rows: Int, cols: Int) {
        (min(max(1, rows), max(1, maxRows)), min(max(1, cols), max(1, maxCols)))
    }

    /// Moves the elements whose ids are in `ids` so they sit immediately
    /// before the element with id `destination` (or at the end when nil),
    /// preserving their relative order. Pure equivalent of applying a
    /// SwiftUI reorder difference, so the rearrange UI stays testable.
    static func movedItems<Element: Identifiable>(
        _ array: [Element],
        withIDs ids: Set<Element.ID>,
        before destination: Element.ID?
    ) -> [Element] {
        let moving = array.filter { ids.contains($0.id) }
        guard !moving.isEmpty else { return array }

        var remaining = array.filter { !ids.contains($0.id) }
        let insertionIndex = destination.flatMap { dest in
            remaining.firstIndex { $0.id == dest }
        } ?? remaining.endIndex
        remaining.insert(contentsOf: moving, at: insertionIndex)
        return remaining
    }

    /// Swaps the elements at two flat positions, ignoring out-of-bounds or
    /// identical indices.
    static func swapped<Element>(_ array: [Element], _ first: Int, _ second: Int) -> [Element] {
        guard first != second,
              array.indices.contains(first),
              array.indices.contains(second) else { return array }
        var result = array
        result.swapAt(first, second)
        return result
    }
}
