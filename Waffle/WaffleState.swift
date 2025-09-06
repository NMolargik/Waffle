//
//  WaffleState.swift
//  Waffle
//
//  Created by Nick Molargik on 9/2/25.
//

import Foundation
import Observation

@Observable
final class WaffleState {
    var waffleRows = [[WaffleCell]]()
    var columnFractions = [Double]()
    
    var selectedCell: WaffleCell? = nil
    var poppedCell: WaffleCell? = nil
    
    var canPopOut: Bool { selectedCell != nil && selectedCell != poppedCell }
    
    var rowCount = 1 {
        didSet {
            if waffleRows.isEmpty {
                let firstRow = [WaffleCell()]
                waffleRows = [firstRow]
            }
            if rowCount < waffleRows.count {
                while waffleRows.count > rowCount {
                    waffleRows.removeLast()
                }
            } else {
                while waffleRows.count < rowCount {
                    let newRow = (0..<colCount).map { _ in WaffleCell() }
                    waffleRows.append(newRow)
                }
            }
        }
    }
    
    var colCount = 1 {
        didSet {
            if waffleRows.isEmpty {
                let firstRow = [WaffleCell()]
                waffleRows = [firstRow]
            }
            if !waffleRows.isEmpty {
                if colCount < waffleRows[0].count {
                    for i in 0..<waffleRows.count {
                        while waffleRows[i].count > colCount {
                            waffleRows[i].removeLast()
                        }
                    }
                } else {
                    for i in 0..<waffleRows.count {
                        while waffleRows[i].count < colCount {
                            waffleRows[i].append(WaffleCell())
                        }
                    }
                }
            }
        }
    }
    
    func select(_ cell: WaffleCell) {
        selectedCell = cell
    }
    
    func popOut(_ cell: WaffleCell) {
        poppedCell = cell
    }
    
    func popBack(poppedCellAddress: String) {
        poppedCell?.loadURL(urlString: poppedCellAddress)
        poppedCell = nil
    }
    
    func isPoppedOut(_ cell: WaffleCell) -> Bool {
        poppedCell == cell
    }
    
    func makeInitialItem() {
        let firstRow = [WaffleCell()]
        self.waffleRows = [firstRow]
        self.selectedCell = firstRow.first
    }
    
    func updateRows() {
        if rowCount < self.waffleRows.count {
            waffleRows.removeLast()
        } else {
            let newRow = (0..<colCount).map { _ in WaffleCell() }
            waffleRows.append(newRow)
        }
    }
    
    func updateCols() {
        if colCount < waffleRows[0].count {
            for i in 0..<waffleRows.count {
                waffleRows[i].removeLast()
            }
        } else {
            for i in 0..<waffleRows.count {
                waffleRows[i].append(WaffleCell())
            }
        }
    }
    
    func flattenedAddresses() -> [String] {
        waffleRows.flatMap { row in
            row.map { cell in
                return cell.address.isEmpty ? "https://www.molargiksoftware.com/#/wafflelanding" : cell.address
            }
        }
    }
    
    func makeSnapshot() -> Snapshot {
        let urls = flattenedAddresses()
        var selectedIndex: Int? = nil
        if let sel = selectedCell {
            outer: for r in 0..<waffleRows.count {
                for c in 0..<waffleRows[r].count {
                    if waffleRows[r][c] == sel {
                        selectedIndex = r * max(1, colCount) + c
                        break outer
                    }
                }
            }
        }
        return Snapshot(rows: max(1, rowCount), cols: max(1, colCount), urls: urls, selectedIndex: selectedIndex)
    }
    
    func apply(snapshot: Snapshot) {
        let rows = max(1, snapshot.rows)
        let cols = max(1, snapshot.cols)
        rowCount = rows
        colCount = cols
        
        waffleRows = (0..<rows).map { _ in
            (0..<cols).map { _ in WaffleCell() }
        }
        
        var idx = 0
        for r in 0..<rows {
            for c in 0..<cols {
                if idx < snapshot.urls.count {
                    waffleRows[r][c].loadURL(urlString: snapshot.urls[idx])
                } else {
                    waffleRows[r][c].loadURL(urlString: "https://apple.com")
                }
                idx += 1
            }
        }
        
        if let si = snapshot.selectedIndex, si >= 0 {
            let r = si / max(1, cols)
            let c = si % max(1, cols)
            if r < waffleRows.count, c < waffleRows[r].count {
                selectedCell = waffleRows[r][c]
            } else {
                selectedCell = waffleRows.first?.first
            }
        } else {
            selectedCell = waffleRows.first?.first
        }
    }
    
    func apply(preset: Preset, syrupEnabled: Bool, maxFreeRows: Int, maxFreeCols: Int) {
        let targetRows = syrupEnabled ? max(1, preset.rows) : min(max(1, preset.rows), maxFreeRows)
        let targetCols = syrupEnabled ? max(1, preset.cols) : min(max(1, preset.cols), maxFreeCols)
        rowCount = targetRows
        colCount = targetCols
        
        waffleRows = (0..<rowCount).map { _ in
            (0..<colCount).map { _ in WaffleCell() }
        }
        
        let urls = preset.urls
        var idx = 0
        for r in 0..<rowCount {
            for c in 0..<colCount {
                if idx < urls.count {
                    let urlString = urls[idx]
                    waffleRows[r][c].loadURL(urlString: urlString)
                } else {
                    waffleRows[r][c].loadURL(urlString: "https://apple.com")
                }
                idx += 1
            }
        }
        
        selectedCell = waffleRows.first?.first
    }
}
