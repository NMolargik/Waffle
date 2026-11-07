//
//  ContentBlockingMenu.swift
//  WaffleFeatureGrid
//
//  "Content Blocking" submenu for the cell context menu (override on/off/follow Settings,
//  plus a per-site exception) and the small blocked-count badge. Free — not Syrup-gated.
//

#if os(iOS)
import SwiftUI
import WaffleCore

public struct ContentBlockingMenu: View {
    let mode: ContentBlockingMode
    let isActive: Bool
    let globalEnabled: Bool
    let siteHasException: Bool
    let canExceptSite: Bool
    let onSelect: (ContentBlockingMode) -> Void
    let onToggleSite: () -> Void

    public init(
        mode: ContentBlockingMode,
        isActive: Bool,
        globalEnabled: Bool,
        siteHasException: Bool,
        canExceptSite: Bool,
        onSelect: @escaping (ContentBlockingMode) -> Void,
        onToggleSite: @escaping () -> Void
    ) {
        self.mode = mode
        self.isActive = isActive
        self.globalEnabled = globalEnabled
        self.siteHasException = siteHasException
        self.canExceptSite = canExceptSite
        self.onSelect = onSelect
        self.onToggleSite = onToggleSite
    }

    public var body: some View {
        Menu {
            Picker(selection: Binding(get: { mode }, set: { onSelect($0) })) {
                Text("Follow Settings").tag(ContentBlockingMode.followGlobal)
                Text("Always Block").tag(ContentBlockingMode.on)
                Text("Never Block").tag(ContentBlockingMode.off)
            } label: {
                EmptyView()
            }
            .pickerStyle(.inline)

            if mode == .followGlobal, globalEnabled, canExceptSite {
                Button(
                    siteHasException ? String(localized: "Block on This Site") : String(localized: "Don't Block on This Site"),
                    systemImage: siteHasException ? "shield" : "shield.slash",
                    action: onToggleSite
                )
            }
        } label: {
            Label {
                Text("Content Blocking")
                Text(isActive ? LocalizedStringKey("On") : LocalizedStringKey("Off"))
            } icon: {
                Image(systemName: isActive ? "shield.lefthalf.filled" : "shield.slash")
            }
        }
    }
}

/// Small pill showing how many items were blocked on the cell's current page.
struct BlockedCountBadge: View {
    let count: Int

    var body: some View {
        Label {
            Text(verbatim: "\(count)")
                .monospacedDigit()
        } icon: {
            Image(systemName: "shield.lefthalf.filled")
        }
        .font(.caption2.weight(.semibold))
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.regularMaterial, in: Capsule())
        .contentTransition(.numericText())
        .animation(.snappy, value: count)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(count) items blocked"))
        .allowsHitTesting(false)
    }
}
#endif
