//
//  PresetsHeaderView.swift
//  Waffle
//
//  Created by Nick Molargik on 9/3/25.
//

import SwiftUI

struct PresetsHeaderView: View {
    var onQuickSave: () -> Void
    var onSaveAs: () -> Void

    var body: some View {
        SidebarSectionHeader(
            title: "Presets",
            icon: "square.grid.3x3.fill",
            iconGradient: [Color.wafflePrimary, Color.waffleSecondary],
            primaryAction: (label: "Quick Save", icon: "square.and.arrow.down.fill", action: onQuickSave),
            secondaryAction: (label: "Save As…", icon: "square.and.pencil", action: onSaveAs)
        )
    }
}

#Preview {
    PresetsHeaderView(onQuickSave: {}, onSaveAs: {})
}
