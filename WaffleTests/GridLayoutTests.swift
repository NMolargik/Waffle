//
//  GridLayoutTests.swift
//  WaffleTests
//

import Foundation
import SwiftUI
import Testing
@testable import Waffle

@Suite("GridLayout")
struct GridLayoutTests {
    // MARK: - resized

    @Test func growsRowsAndColumns() {
        var counter = 0
        let grid = GridLayout.resized([[1]], rows: 3, cols: 2) {
            counter += 1
            return counter * 100
        }
        #expect(grid.count == 3)
        #expect(grid.allSatisfy { $0.count == 2 })
        #expect(grid[0][0] == 1)
    }

    @Test func shrinksRowsAndColumnsPreservingTopLeft() {
        let grid = [[1, 2, 3], [4, 5, 6], [7, 8, 9]]
        let result = GridLayout.resized(grid, rows: 2, cols: 2) { 0 }
        #expect(result == [[1, 2], [4, 5]])
    }

    @Test func growsFromEmptyGrid() {
        let result = GridLayout.resized([[Int]](), rows: 2, cols: 2) { 7 }
        #expect(result == [[7, 7], [7, 7]])
    }

    @Test func clampsDegenerateSizesToOne() {
        let result = GridLayout.resized([[1]], rows: 0, cols: -2) { 0 }
        #expect(result == [[1]])
    }

    // MARK: - index / position

    @Test(arguments: [
        (0, 0, 3, 0),
        (1, 2, 3, 5),
        (2, 0, 3, 6)
    ])
    func indexAndPositionRoundTrip(row: Int, column: Int, cols: Int, expected: Int) {
        let flat = GridLayout.index(row: row, column: column, columnCount: cols)
        #expect(flat == expected)
        let position = GridLayout.position(of: flat, columnCount: cols)
        #expect(position.row == row)
        #expect(position.column == column)
    }

    // MARK: - rowMajorURLs

    @Test func padsMissingURLsWithFill() {
        let layout = GridLayout.rowMajorURLs(["a", "b"], rows: 2, cols: 2, fill: "x")
        #expect(layout == [["a", "b"], ["x", "x"]])
    }

    @Test func dropsExtraURLs() {
        let layout = GridLayout.rowMajorURLs(["a", "b", "c", "d", "e"], rows: 1, cols: 2, fill: "x")
        #expect(layout == [["a", "b"]])
    }

    // MARK: - clamped

    @Test(arguments: [
        (5, 5, 4, 4, 4, 4),
        (0, 3, 4, 4, 1, 3),
        (2, 2, 2, 2, 2, 2)
    ])
    func clampsGridSizes(rows: Int, cols: Int, maxRows: Int, maxCols: Int, expectedRows: Int, expectedCols: Int) {
        let result = GridLayout.clamped(rows: rows, cols: cols, maxRows: maxRows, maxCols: maxCols)
        #expect(result.rows == expectedRows)
        #expect(result.cols == expectedCols)
    }

    // MARK: - moved

    @Test func movesElementForward() {
        // Matches SwiftUI onMove semantics: destination is the slot before removal.
        let result = GridLayout.moved(["a", "b", "c", "d"], fromOffsets: IndexSet(integer: 0), toOffset: 3)
        #expect(result == ["b", "c", "a", "d"])
    }

    @Test func movesElementBackward() {
        let result = GridLayout.moved(["a", "b", "c", "d"], fromOffsets: IndexSet(integer: 3), toOffset: 0)
        #expect(result == ["d", "a", "b", "c"])
    }

    @Test func movesMultipleElements() {
        let result = GridLayout.moved(["a", "b", "c", "d"], fromOffsets: IndexSet([0, 1]), toOffset: 4)
        #expect(result == ["c", "d", "a", "b"])
    }

    @Test func ignoresOutOfBoundsOffsets() {
        let result = GridLayout.moved(["a"], fromOffsets: IndexSet(integer: 9), toOffset: 0)
        #expect(result == ["a"])
    }

    @Test func matchesSwiftUIMoveSemantics() {
        // Verify against Foundation's own RangeReplaceableCollection implementation
        // for a spread of cases.
        for (source, dest) in [(0, 2), (2, 0), (1, 3), (0, 1)] {
            var expected = ["a", "b", "c", "d"]
            expected.move(fromOffsets: IndexSet(integer: source), toOffset: dest)
            let actual = GridLayout.moved(["a", "b", "c", "d"], fromOffsets: IndexSet(integer: source), toOffset: dest)
            #expect(actual == expected, "move \(source) -> \(dest)")
        }
    }

    // MARK: - movedItems (reorder by id)

    private static func rearrangeCells(_ urls: [String]) -> [RearrangeCell] {
        urls.map { RearrangeCell(id: UUID(), url: $0) }
    }

    @Test func movedItemsInsertsBeforeDestination() {
        let cells = Self.rearrangeCells(["a", "b", "c", "d"])
        let result = GridLayout.movedItems(cells, withIDs: [cells[3].id], before: cells[1].id)
        #expect(result.map(\.url) == ["a", "d", "b", "c"])
    }

    @Test func movedItemsAppendsWhenDestinationIsNil() {
        let cells = Self.rearrangeCells(["a", "b", "c", "d"])
        let result = GridLayout.movedItems(cells, withIDs: [cells[0].id], before: nil)
        #expect(result.map(\.url) == ["b", "c", "d", "a"])
    }

    @Test func movedItemsPreservesRelativeOrderOfMovedGroup() {
        let cells = Self.rearrangeCells(["a", "b", "c", "d"])
        let result = GridLayout.movedItems(cells, withIDs: [cells[0].id, cells[2].id], before: cells[3].id)
        #expect(result.map(\.url) == ["b", "a", "c", "d"])
    }

    @Test func movedItemsIgnoresUnknownIDs() {
        let cells = Self.rearrangeCells(["a", "b"])
        let result = GridLayout.movedItems(cells, withIDs: [UUID()], before: cells[0].id)
        #expect(result.map(\.url) == ["a", "b"])
    }

    // MARK: - swapped

    @Test func swappedExchangesTwoElements() {
        #expect(GridLayout.swapped(["a", "b", "c"], 0, 2) == ["c", "b", "a"])
    }

    @Test func swappedIgnoresInvalidIndices() {
        #expect(GridLayout.swapped(["a", "b"], 0, 5) == ["a", "b"])
        #expect(GridLayout.swapped(["a", "b"], 1, 1) == ["a", "b"])
    }

    // MARK: - RearrangeCell

    @Test func rearrangeCellClearEmptiesSlot() {
        var cell = RearrangeCell(id: UUID(), url: "https://apple.com", title: "Apple")
        #expect(!cell.isEmpty)
        cell.clear()
        #expect(cell.isEmpty)
        #expect(cell.title.isEmpty)
    }
}
