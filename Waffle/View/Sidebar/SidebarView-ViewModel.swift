//
//  SidebarView-ViewModel.swift
//  Waffle
//
//  Created by Nick Molargik on 9/3/25.
//

import Foundation

extension SidebarView {
    @Observable
    class ViewModel {
        var showingPresetNamePrompt = false
        var newPresetName: String = ""
        
        var showingBookmarkNamePrompt = false
        var newBookmarkTitle: String = ""
        var newBookmarkURLString: String = ""
        var bookmarkToEdit: Bookmark? = nil

        func beginPresetNaming() {
            newPresetName = ""
            showingPresetNamePrompt = true
        }

        func beginPresetRenaming(existingName: String) {
            newPresetName = existingName
            showingPresetNamePrompt = true
        }

        func resetPresetPrompt() {
            showingPresetNamePrompt = false
            newPresetName = ""
        }

        func beginBookmarkCreation() {
            bookmarkToEdit = nil
            newBookmarkTitle = ""
            newBookmarkURLString = ""
            showingBookmarkNamePrompt = true
        }

        func beginBookmarkEditing(_ bookmark: Bookmark) {
            bookmarkToEdit = bookmark
            newBookmarkTitle = bookmark.title
            newBookmarkURLString = bookmark.urlString
            showingBookmarkNamePrompt = true
        }

        func resetBookmarkPrompt() {
            showingBookmarkNamePrompt = false
            bookmarkToEdit = nil
            newBookmarkTitle = ""
            newBookmarkURLString = ""
        }
    }
}
