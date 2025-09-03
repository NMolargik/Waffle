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
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @AppStorage("searchProvider") var searchProviderRawValue: String = SearchProvider.google.rawValue
    @State private var viewModel = SettingsView.ViewModel()

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Button {
                        coordinator.presentSyrupSheet = true
                    } label: {
                        HStack {
                            Label("Syrup", systemImage: "drop.fill")
                                .foregroundStyle(.primary)
                            Spacer()
                            if coordinator.isSyrupEnabled {
                                HStack(spacing: 6) {
                                    Image(systemName: "checkmark.seal.fill")
                                        .foregroundStyle(.green)
                                    Text("Purchased")
                                        .foregroundStyle(.secondary)
                                }
                            } else {
                                HStack(spacing: 6) {
                                    Image(systemName: "cart")
                                        .foregroundStyle(.brown)
                                    Text("Not Purchased")
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Image(systemName: "chevron.right")
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .buttonStyle(.plain)
                }

                Section("Search") {
                    Picker("Default Search Engine", selection: $searchProviderRawValue) {
                        ForEach(SearchProvider.allCases, id: \.self) { provider in
                            Text(provider.displayName).tag(provider.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                Section("Data") {
                    Button(role: .destructive) {
                        viewModel.showDeletePresetsConfirm = true
                    } label: {
                        Text("Delete All Presets")
                    }
                    Button(role: .destructive) {
                        viewModel.showDeleteBookmarksConfirm = true
                    } label: {
                        Text("Delete All Bookmarks")
                    }
                }
                
                Section("About") {
                    HStack {
                        Text("Waffle")
                        Spacer()
                        Text(viewModel.appVersionString)
                            .foregroundStyle(.secondary)
                    }
                    
                    Button {
                        openInApp("https://www.linkedin.com/in/nicholas-molargik/")
                    } label: {
                        HStack {
                            Text("Developer")
                            Spacer()
                            Text("Nicholas Molargik")
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
                            Text("Molargik Software LLC")
                                .foregroundStyle(.blue)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
            .alert("Delete All Bookmarks?", isPresented: $viewModel.showDeleteBookmarksConfirm) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    deleteAllBookmarks()
                }
            } message: {
                Text("This action will permanently remove all bookmarks.")
            }
            .alert("Delete All Presets?", isPresented: $viewModel.showDeletePresetsConfirm) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    deleteAllPresets()
                }
            } message: {
                Text("This action will permanently remove all presets.")
            }
        }
    }

    // Open a URL inside the app's own browser UI by loading it in the selected cell.
    private func openInApp(_ urlString: String) {
        coordinator.waffleState.selectedCell?.loadURL(urlString: urlString)
    }

    private func deleteAllBookmarks() {
        do {
            let descriptor = FetchDescriptor<Bookmark>()
            let all = try modelContext.fetch(descriptor)
            all.forEach { modelContext.delete($0) }
            try modelContext.save()
        } catch {
            print("Failed to delete all bookmarks: \(error)")
        }
    }

    private func deleteAllPresets() {
        do {
            let descriptor = FetchDescriptor<Preset>()
            let all = try modelContext.fetch(descriptor)
            all.forEach { modelContext.delete($0) }
            try modelContext.save()
        } catch {
            print("Failed to delete all presets: \(error)")
        }
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Bookmark.self, Preset.self, configurations: config)

    // Coordinator + Store for environment
    let storeManager = StoreManager()
    let coordinator = WaffleCoordinator(store: storeManager)

    return SettingsView()
        .modelContainer(container)
        .environment(coordinator)
        .frame(minWidth: 420, minHeight: 420)
}
