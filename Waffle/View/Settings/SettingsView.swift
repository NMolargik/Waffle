//
//  SettingsView.swift
//  Waffle
//
//  Created by Nick Molargik on 9/3/25.
//

import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(WaffleCoordinator.self) private var coordinator
    @Environment(\.dismiss) private var dismiss

    @AppStorage("searchProvider") var searchProviderRawValue: String = SearchProvider.google.rawValue
    @State private var showDeleteBookmarksConfirm = false
    @State private var showDeletePresetsConfirm = false

    private var appVersionString: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
        return String(localized: "Version \(version) (\(build))")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Button {
                        if !coordinator.isSyrupEnabled {
                            coordinator.requestSyrup()
                        }
                    } label: {
                        HStack {
                            Label(String(localized: "Syrup"), systemImage: "drop.fill")
                                .foregroundStyle(.primary)
                            Spacer()
                            if coordinator.isSyrupEnabled {
                                HStack(spacing: 6) {
                                    Image(systemName: "checkmark.seal.fill")
                                        .foregroundStyle(.green)
                                    Text("Purchased. Thank you!")
                                        .foregroundStyle(.secondary)
                                }
                            } else {
                                HStack(spacing: 6) {
                                    Image(systemName: "cart")
                                        .foregroundStyle(.waffleTertiary)
                                    Text("Not Purchased")
                                        .foregroundStyle(.secondary)
                                }

                                Image(systemName: "chevron.right")
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(coordinator.isSyrupEnabled) // Prevent interaction when already purchased
                    .accessibilityHint(coordinator.isSyrupEnabled ? Text("") : Text("Opens the Syrup purchase sheet"))
                }

                Section(String(localized: "Search")) {
                    Picker(String(localized: "Default Search Engine"), selection: $searchProviderRawValue) {
                        ForEach(SearchProvider.allCases, id: \.self) { provider in
                            Text(provider.displayName).tag(provider.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section(String(localized: "Data")) {
                    Button(role: .destructive) {
                        showDeletePresetsConfirm = true
                    } label: {
                        Text("Delete All Presets")
                    }
                    Button(role: .destructive) {
                        showDeleteBookmarksConfirm = true
                    } label: {
                        Text("Delete All Bookmarks")
                    }
                }

                Section(String(localized: "About")) {
                    HStack {
                        Text("Waffle")
                        Spacer()
                        Text(appVersionString)
                            .foregroundStyle(.secondary)
                    }

                    Button {
                        openInApp("https://www.linkedin.com/in/nicholas-molargik/")
                    } label: {
                        HStack {
                            Text("Developer")
                            Spacer()
                            Text(verbatim: "Nicholas Molargik")
                                .foregroundStyle(.blue)
                        }
                    }
                    .buttonStyle(.plain)

                    Button {
                        openInApp("https://molargiksoftware.com")
                    } label: {
                        HStack {
                            Text("Company")
                            Spacer()
                            Text(verbatim: "Molargik Software LLC")
                                .foregroundStyle(.blue)
                        }
                    }
                    .buttonStyle(.plain)
                }

                #if DEBUG
                Section(String(localized: "Debug")) {
                    Button {
                        coordinator.library.addExampleData()
                    } label: {
                        Label(String(localized: "Add Example Bookmarks & Presets"), systemImage: "plus.square.on.square")
                    }
                }
                #endif
            }
            .navigationTitle(Text("Settings"))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(String(localized: "Close")) {
                        dismiss()
                    }
                }
            }
            .alert(Text("Delete All Bookmarks?"), isPresented: $showDeleteBookmarksConfirm) {
                Button(String(localized: "Cancel"), role: .cancel) { }
                Button(String(localized: "Delete"), role: .destructive) {
                    coordinator.library.deleteAllBookmarks()
                }
            } message: {
                Text("This action will permanently remove all bookmarks.")
            }
            .alert(Text("Delete All Presets?"), isPresented: $showDeletePresetsConfirm) {
                Button(String(localized: "Cancel"), role: .cancel) { }
                Button(String(localized: "Delete"), role: .destructive) {
                    coordinator.library.deleteAllPresets()
                }
            } message: {
                Text("This action will permanently remove all presets.")
            }
        }
    }

    // Open a URL inside the app's own browser UI by loading it in the selected cell.
    private func openInApp(_ urlString: String) {
        coordinator.waffleState.loadInSelectedCell(urlString)
        dismiss()
    }
}

#Preview {
    SettingsView()
        .environment(PreviewSupport.makeCoordinator())
        .frame(minWidth: 420, minHeight: 420)
}
