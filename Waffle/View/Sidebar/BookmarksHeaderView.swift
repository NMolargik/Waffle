//
//  BookmarksHeaderView.swift
//  Waffle
//
//  Created by Nick Molargik on 9/3/25.
//

import SwiftUI

struct BookmarksHeaderView: View {
    var onQuickSaveCurrent: () -> Void
    var onSaveAs: () -> Void

    var body: some View {
        SidebarSectionHeader(
            title: "Bookmarks",
            icon: "bookmark.fill",
            iconGradient: [Color.wafflePrimary, Color.waffleSecondary],
            primaryAction: (label: "Save As…", icon: "square.and.pencil", action: onSaveAs),
            secondaryAction: (label: "Quick Save", icon: "square.and.arrow.down.fill", action: onQuickSaveCurrent)
        )
    }
}

#Preview {
    BookmarksHeaderView(onQuickSaveCurrent: {}, onSaveAs: {})
}
