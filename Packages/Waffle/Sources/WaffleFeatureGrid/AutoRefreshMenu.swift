//
//  AutoRefreshMenu.swift
//  WaffleFeatureGrid
//
//  "Auto-Refresh" submenu shared by the cell context menu and the toolbar reload menu.
//  Free feature — not gated by Syrup.
//

#if os(iOS)
import SwiftUI
import WaffleCore

public struct AutoRefreshMenu: View {
    let selection: RefreshInterval
    let onSelect: (RefreshInterval) -> Void

    public init(selection: RefreshInterval, onSelect: @escaping (RefreshInterval) -> Void) {
        self.selection = selection
        self.onSelect = onSelect
    }

    public var body: some View {
        Menu {
            Picker(selection: Binding(get: { selection }, set: { onSelect($0) })) {
                ForEach(RefreshInterval.allCases, id: \.self) { interval in
                    Text(interval.title).tag(interval)
                }
            } label: {
                EmptyView()
            }
            .pickerStyle(.inline)
        } label: {
            Label {
                Text("Auto-Refresh")
                if selection != .off {
                    Text(selection.title)
                }
            } icon: {
                Image(systemName: selection == .off ? "timer" : "timer.circle.fill")
            }
        }
    }
}

public extension RefreshInterval {
    /// Menu label for the interval.
    var title: LocalizedStringKey {
        switch self {
        case .off: "Off"
        case .thirtySeconds: "Every 30 seconds"
        case .oneMinute: "Every minute"
        case .fiveMinutes: "Every 5 minutes"
        case .fifteenMinutes: "Every 15 minutes"
        }
    }
}
#endif
