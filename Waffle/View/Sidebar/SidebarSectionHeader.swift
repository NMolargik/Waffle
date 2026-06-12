//
//  SidebarSectionHeader.swift
//  Waffle
//
//  Created by Nick Molargik on 9/3/25.
//

import SwiftUI

/// A reusable header component for sidebar sections (Bookmarks, Presets, etc.)
struct SidebarSectionHeader: View {
    let title: LocalizedStringKey
    let icon: String
    let iconGradient: [Color]
    let primaryAction: (label: LocalizedStringKey, icon: String, action: () -> Void)
    let secondaryAction: (label: LocalizedStringKey, icon: String, action: () -> Void)

    var body: some View {
        HStack {
            Group {
                Image(systemName: icon)
                    .foregroundStyle(LinearGradient(colors: iconGradient, startPoint: .top, endPoint: .bottom))
                    .frame(width: 40)
                Text(title)
            }
            .fontWeight(.semibold)
            .font(.title2)
            .bold()

            Spacer()

            Menu {
                Button(primaryAction.label, systemImage: primaryAction.icon) { primaryAction.action() }
                Button(secondaryAction.label, systemImage: secondaryAction.icon) { secondaryAction.action() }
            } label: {
                HStack {
                    Image(systemName: "plus")
                    Text("New")
                }
                .bold()
                .padding(10)
                .foregroundStyle(Color.primary)
                .glassEffect(.regular.interactive())
            }
            .menuStyle(.borderlessButton)
            .buttonStyle(.glass)
        }
        .padding(10)
        .padding(.horizontal, 10)
    }
}

#Preview {
    SidebarSectionHeader(
        title: "Bookmarks",
        icon: "bookmark.fill",
        iconGradient: [Color.wafflePrimary, Color.waffleSecondary],
        primaryAction: (label: "Save As…", icon: "square.and.pencil", action: {}),
        secondaryAction: (label: "Quick Save", icon: "square.and.arrow.down.fill", action: {})
    )
}
