//
//  PresetsListView.swift
//  WaffleFeatureSidebar
//
//  Preset rows with apply/overwrite/rename/delete, plus the Syrup upsell card for free
//  users (gating state injected — no coordinator dependency).
//

#if os(iOS)
import SwiftUI
import WaffleCore
import WaffleDesignSystem

struct PresetsListView: View {
    var presets: [Preset]
    var isSyrupEnabled: Bool
    var requestSyrup: () -> Void
    var applyPreset: (Preset) -> Void
    var overwritePreset: (Preset) -> Void
    var onRename: (Preset) -> Void
    var onDelete: (Preset) -> Void

    var body: some View {
        List {
            if !isSyrupEnabled {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Syrup Required", systemImage: "drop.fill")
                            .font(.headline)
                            .tint(.waffleTertiary)

                        Text("Presets are part of Syrup. To apply, update, or manage presets you'll need Syrup.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        HStack {
                            Spacer()

                            Button {
                                requestSyrup()
                            } label: {
                                Text("Purchase")
                            }
                            .buttonStyle(.wafflePrimary)

                            Spacer()
                        }
                    }
                    .padding(.vertical, 6)
                }
                .padding()
                .background {
                    Rectangle()
                        .foregroundStyle(.thickMaterial)
                        .cornerRadius(20)
                }
            } else if presets.isEmpty {
                Section {
                    VStack(spacing: 10) {
                        Image(systemName: "square.grid.3x3.slash")
                            .font(.system(size: 32, weight: .regular))
                            .foregroundStyle(.secondary)
                        Text("No presets yet")
                            .font(.headline)
                        Text("Save your current grid layout as a preset to quickly restore it later.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 24)
                    .listRowInsets(EdgeInsets(top: 16, leading: 12, bottom: 16, trailing: 12))
                } header: {
                    Color.clear.frame(height: 0.1)
                }
            }

            ForEach(presets) { preset in
                Button {
                    applyPreset(preset)
                } label: {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(preset.name.isEmpty ? String(localized: "Untitled Preset") : preset.name)
                                .font(.headline)
                            HStack {
                                Image(systemName: "square.grid.3x3.fill")
                                Text("\(preset.rows)x\(preset.cols)")
                            }
                            .font(.caption)
                            .padding(.vertical, 8)
                            .padding(.horizontal)
                            .background {
                                Rectangle()
                                    .foregroundStyle(.waffleSecondary)
                                    .cornerRadius(20)
                            }
                        }
                        Spacer()
                        Image(systemName: "arrow.right")
                            .bold()
                            .foregroundStyle(Color.primary)
                    }
                }
                .buttonStyle(.plain)
                .contextMenu {
                    Button(String(localized: "Apply")) { applyPreset(preset) }
                    Button(String(localized: "Rename")) { onRename(preset) }
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
#endif
