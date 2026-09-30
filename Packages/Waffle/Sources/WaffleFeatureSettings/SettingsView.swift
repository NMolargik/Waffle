//
//  SettingsView.swift
//  WaffleFeatureSettings
//
//  Search engine, Syrup status, destructive data actions, and about links. Data actions
//  go through `SettingsModel`; Syrup gating and in-app link opening are injected.
//

#if os(iOS)
import SwiftUI
import WaffleCore
import WaffleDesignSystem

public struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    private let model: SettingsModel
    private let isSyrupEnabled: Bool
    private let requestSyrup: () -> Void
    /// Loads a URL into the selected grid cell (the app browses its own links).
    private let openInApp: (String) -> Void

    @AppStorage("searchProvider") private var searchProviderRawValue: String = SearchProvider.google.rawValue
    @State private var showDeleteBookmarksConfirm = false
    @State private var showDeletePresetsConfirm = false

    public init(
        model: SettingsModel,
        isSyrupEnabled: Bool,
        requestSyrup: @escaping () -> Void,
        openInApp: @escaping (String) -> Void
    ) {
        self.model = model
        self.isSyrupEnabled = isSyrupEnabled
        self.requestSyrup = requestSyrup
        self.openInApp = openInApp
    }

    private var appVersionString: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
        return String(localized: "Version \(version) (\(build))")
    }

    public var body: some View {
        NavigationStack {
            Form {
                Section {
                    Button {
                        if !isSyrupEnabled {
                            requestSyrup()
                        }
                    } label: {
                        HStack {
                            Label(String(localized: "Syrup"), systemImage: "drop.fill")
                                .foregroundStyle(.primary)
                            Spacer()
                            if isSyrupEnabled {
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
                    .disabled(isSyrupEnabled) // Prevent interaction when already purchased
                    .accessibilityHint(isSyrupEnabled ? Text("") : Text("Opens the Syrup purchase sheet"))
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
                        openLink("https://www.linkedin.com/in/nicholas-molargik/")
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
                        openLink("https://molargiksoftware.com")
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
                        model.addExampleData()
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
                    model.deleteAllBookmarks()
                }
            } message: {
                Text("This action will permanently remove all bookmarks.")
            }
            .alert(Text("Delete All Presets?"), isPresented: $showDeletePresetsConfirm) {
                Button(String(localized: "Cancel"), role: .cancel) { }
                Button(String(localized: "Delete"), role: .destructive) {
                    model.deleteAllPresets()
                }
            } message: {
                Text("This action will permanently remove all presets.")
            }
        }
    }

    private func openLink(_ urlString: String) {
        openInApp(urlString)
        dismiss()
    }
}
#endif
