//
//  PresetsListView.swift
//  Waffle
//
//  Created by Nick Molargik on 9/3/25.
//

import SwiftUI

struct PresetsListView: View {
    @Environment(WaffleCoordinator.self) private var coordinator

    var presets: [Preset]
    var applyPreset: (Preset) -> Void
    var overwritePreset: (Preset) -> Void
    var onRename: (Preset) -> Void
    var onDelete: (Preset) -> Void
    
    var body: some View {
        List {
            if !coordinator.isSyrupEnabled {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Syrup Required", systemImage: "drop.fill")
                            .font(.headline)
                            .tint(.brown)
                        
                        Text("Presets are part of Syrup. To apply, update, or manage presets you’ll need Syrup.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        HStack {
                            Spacer()
                            
                            Button {
                                coordinator.requestSyrup()
                            } label: {
                                Text("Purchase")
                                    .foregroundStyle(.white)
                            }
                            .buttonStyle(.borderedProminent)
                            .foregroundStyle(.brown)
                            
                            Spacer()
                        }
                    }
                    .padding(.vertical, 6)
                }
            }

            ForEach(presets) { preset in
                Button {
                    applyPreset(preset)
                } label: {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(preset.name.isEmpty ? "Untitled Preset" : preset.name)
                                .font(.headline)
                            HStack {
                                Image(systemName: "square.grid.3x3.fill")
                                Text("\(preset.rows)x\(preset.cols)")
                            }
                            .foregroundStyle(Color.waffleTertiary)
                            .font(.caption)
                        }
                        Spacer()
                        Image(systemName: "arrow.right")
                            .bold()
                            .foregroundStyle(Color.primary)
                    }
                }
                .buttonStyle(.plain)
                .contextMenu {
                    Button("Apply") { applyPreset(preset) }
                    Button("Rename") { onRename(preset) }
                    Button(role: .destructive) {
                        onDelete(preset)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                    Button {
                        overwritePreset(preset)
                    } label: {
                        Label("Update", systemImage: "square.and.arrow.down")
                    }
                    .tint(.blue)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        onDelete(preset)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
    }
}

#Preview {
    let presets: [Preset] = [
        Preset(name: "News 2x2", rows: 2, cols: 2, urls: [
            "https://www.apple.com",
            "https://www.bbc.com",
            "https://www.cnn.com",
            "https://www.theverge.com"
        ]),
        Preset(name: "Work 1x3", rows: 1, cols: 3, urls: [
            "https://mail.google.com",
            "https://calendar.google.com",
            "https://github.com"
        ]),
        Preset(name: "Research 3x2", rows: 3, cols: 2, urls: [
            "https://developer.apple.com",
            "https://swift.org",
            "https://forums.swift.org",
            "https://www.raywenderlich.com",
            "https://stackoverflow.com",
            "https://www.hackingwithswift.com"
        ]),
        Preset(name: "", rows: 2, cols: 1, urls: [
            "https://example.com",
            "https://example.org"
        ]),
        Preset(name: "Tall 5x1", rows: 5, cols: 1, urls: [
            "https://site1.com","https://site2.com","https://site3.com","https://site4.com","https://site5.com"
        ])
    ]

    let store = StoreManager()
    let coordinator = WaffleCoordinator(store: store)

    return PresetsListView(
        presets: presets,
        applyPreset: { p in print("[Preview] Apply:", p.name.isEmpty ? "Untitled Preset" : p.name) },
        overwritePreset: { p in print("[Preview] Overwrite with current grid:", p.name.isEmpty ? "Untitled Preset" : p.name) },
        onRename: { p in print("[Preview] Rename:", p.name.isEmpty ? "Untitled Preset" : p.name) },
        onDelete: { p in print("[Preview] Delete:", p.name.isEmpty ? "Untitled Preset" : p.name) }
    )
    .environment(coordinator)
    .padding()
}
