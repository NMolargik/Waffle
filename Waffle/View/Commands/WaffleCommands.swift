//
//  WaffleCommands.swift
//  Waffle
//
//  Menu bar commands for iPadOS 26+ and hardware keyboards.
//

import SwiftUI
import WebKit

/// App menu bar: grid sizing, navigation, and library actions.
struct WaffleCommands: Commands {
    let coordinator: WaffleCoordinator

    var body: some Commands {
        CommandMenu(Text("Grid", comment: "Menu bar title for grid commands")) {
            Button(String(localized: "Add Row"), systemImage: "rectangle.split.1x2.fill") {
                coordinator.setGridSize(rows: coordinator.waffleState.rowCount + 1, cols: coordinator.waffleState.colCount)
            }
            .keyboardShortcut(.downArrow, modifiers: [.command, .shift])
            .disabled(coordinator.waffleState.rowCount >= coordinator.maxRows)

            Button(String(localized: "Remove Row"), systemImage: "rectangle.split.1x2") {
                coordinator.setGridSize(rows: coordinator.waffleState.rowCount - 1, cols: coordinator.waffleState.colCount)
            }
            .keyboardShortcut(.upArrow, modifiers: [.command, .shift])
            .disabled(coordinator.waffleState.rowCount <= 1)

            Divider()

            Button(String(localized: "Add Column"), systemImage: "square.split.2x1.fill") {
                coordinator.setGridSize(rows: coordinator.waffleState.rowCount, cols: coordinator.waffleState.colCount + 1)
            }
            .keyboardShortcut(.rightArrow, modifiers: [.command, .shift])
            .disabled(coordinator.waffleState.colCount >= coordinator.maxCols)

            Button(String(localized: "Remove Column"), systemImage: "square.split.2x1") {
                coordinator.setGridSize(rows: coordinator.waffleState.rowCount, cols: coordinator.waffleState.colCount - 1)
            }
            .keyboardShortcut(.leftArrow, modifiers: [.command, .shift])
            .disabled(coordinator.waffleState.colCount <= 1)
        }

        CommandMenu(Text("Navigation", comment: "Menu bar title for navigation commands")) {
            Button(String(localized: "Back"), systemImage: "chevron.backward") {
                coordinator.waffleState.selectedCell?.goBack()
            }
            .keyboardShortcut("[", modifiers: .command)
            .disabled(coordinator.waffleState.selectedCell?.canGoBack != true)

            Button(String(localized: "Forward"), systemImage: "chevron.forward") {
                coordinator.waffleState.selectedCell?.goForward()
            }
            .keyboardShortcut("]", modifiers: .command)
            .disabled(coordinator.waffleState.selectedCell?.canGoForward != true)

            Button(String(localized: "Reload Page"), systemImage: "arrow.clockwise") {
                coordinator.waffleState.selectedCell?.reloadCell()
            }
            .keyboardShortcut("r", modifiers: .command)
            .disabled(coordinator.waffleState.selectedCell == nil)
        }

        CommandMenu(Text("Library", comment: "Menu bar title for bookmark and preset commands")) {
            Button(String(localized: "Bookmark Current Page"), systemImage: "bookmark.fill") {
                guard let cell = coordinator.waffleState.selectedCell else { return }
                coordinator.library.addBookmark(urlString: cell.address, title: cell.page.title)
            }
            .keyboardShortcut("d", modifiers: .command)
            .disabled(coordinator.waffleState.selectedCell?.address.isEmpty != false)

            Button(String(localized: "Save Grid as Preset"), systemImage: "square.grid.3x3.fill") {
                guard coordinator.canMakePresets else {
                    coordinator.requestSyrup()
                    return
                }
                coordinator.library.savePreset(
                    named: nil,
                    rows: coordinator.waffleState.rowCount,
                    cols: coordinator.waffleState.colCount,
                    urls: coordinator.waffleState.flattenedAddresses()
                )
            }
            .keyboardShortcut("s", modifiers: [.command, .shift])
        }
    }
}
