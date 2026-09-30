//
//  SidebarSectionHeader.swift
//  WaffleFeatureSidebar
//
//  A reusable header component for sidebar sections (Bookmarks, Presets, etc.)
//

#if os(iOS)
import SwiftUI
import WaffleDesignSystem

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
#endif
