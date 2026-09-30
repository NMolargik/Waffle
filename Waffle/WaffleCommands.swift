//
//  WaffleCommands.swift
//  Waffle
//
//  Menu bar commands for iPadOS 26+ and hardware keyboards.
//

import SwiftUI
import WaffleComposition
import WaffleCore
import WaffleDesignSystem
import WaffleFeatureGrid

/// App menu bar: grid sizing, navigation, and library actions.
struct WaffleCommands: Commands {
    let session: SessionController

    private var grid: GridModel { session.grid }

    var body: some Commands {
        CommandMenu(Text("Grid", comment: "Menu bar title for grid commands")) {
            Button(String(localized: "Add Row"), systemImage: "rectangle.split.1x2.fill") {
                session.setGridSize(rows: grid.rowCount + 1, cols: grid.colCount)
            }
            .keyboardShortcut(.downArrow, modifiers: [.command, .shift])
            .disabled(grid.rowCount >= session.maxRows)

            Button(String(localized: "Remove Row"), systemImage: "rectangle.split.1x2") {
                session.setGridSize(rows: grid.rowCount - 1, cols: grid.colCount)
            }
            .keyboardShortcut(.upArrow, modifiers: [.command, .shift])
            .disabled(grid.rowCount <= 1)

            Divider()

            Button(String(localized: "Add Column"), systemImage: "square.split.2x1.fill") {
                session.setGridSize(rows: grid.rowCount, cols: grid.colCount + 1)
            }
            .keyboardShortcut(.rightArrow, modifiers: [.command, .shift])
            .disabled(grid.colCount >= session.maxCols)

            Button(String(localized: "Remove Column"), systemImage: "square.split.2x1") {
                session.setGridSize(rows: grid.rowCount, cols: grid.colCount - 1)
            }
            .keyboardShortcut(.leftArrow, modifiers: [.command, .shift])
            .disabled(grid.colCount <= 1)
        }

        CommandMenu(Text("Navigation", comment: "Menu bar title for navigation commands")) {
            Button(String(localized: "Back"), systemImage: "chevron.backward") {
                grid.selectedCell?.goBack()
            }
            .keyboardShortcut("[", modifiers: .command)
            .disabled(grid.selectedCell?.canGoBack != true)

            Button(String(localized: "Forward"), systemImage: "chevron.forward") {
                grid.selectedCell?.goForward()
            }
            .keyboardShortcut("]", modifiers: .command)
            .disabled(grid.selectedCell?.canGoForward != true)

            Button(String(localized: "Reload Page"), systemImage: "arrow.clockwise") {
                grid.selectedCell?.reloadCell()
            }
            .keyboardShortcut("r", modifiers: .command)
            .disabled(grid.selectedCell == nil)
        }

        CommandMenu(Text("Library", comment: "Menu bar title for bookmark and preset commands")) {
            Button(String(localized: "Bookmark Current Page"), systemImage: "bookmark.fill") {
                session.bookmarkSelectedPage()
            }
            .keyboardShortcut("d", modifiers: .command)
            .disabled(grid.selectedCell?.address.isEmpty != false)

            Button(String(localized: "Save Grid as Preset"), systemImage: "square.grid.3x3.fill") {
                session.saveCurrentGridAsPreset()
            }
            .keyboardShortcut("s", modifiers: [.command, .shift])
        }
    }
}
