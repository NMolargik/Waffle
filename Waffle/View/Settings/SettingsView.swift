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
                        if !coordinator.isSyrupEnabled {
                            coordinator.presentSyrupSheet = true
                        }
                    } label: {
                        HStack {
                            Label("Syrup", systemImage: "drop.fill")
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

                #if DEBUG
                Section("Debug") {
                    Button {
                        addExampleData()
                    } label: {
                        Label("Add Example Bookmarks & Presets", systemImage: "plus.square.on.square")
                    }
                }
                #endif
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
            coordinator.errorHandler.showToast("All bookmarks deleted")
        } catch {
            coordinator.errorHandler.showDataError("Failed to delete bookmarks: \(error.localizedDescription)")
        }
    }

    private func deleteAllPresets() {
        do {
            let descriptor = FetchDescriptor<Preset>()
            let all = try modelContext.fetch(descriptor)
            all.forEach { modelContext.delete($0) }
            try modelContext.save()
            coordinator.errorHandler.showToast("All presets deleted")
        } catch {
            coordinator.errorHandler.showDataError("Failed to delete presets: \(error.localizedDescription)")
        }
    }

    #if DEBUG
    private func addExampleData() {
        do {
            // Example Bookmarks
            let exampleBookmarks: [(url: String, title: String)] = [
                ("https://www.apple.com", "Apple"),
                ("https://www.google.com", "Google"),
                ("https://www.github.com", "GitHub"),
                ("https://www.wikipedia.org", "Wikipedia"),
                ("https://www.youtube.com", "YouTube"),
                ("https://news.ycombinator.com", "Hacker News")
            ]

            for (index, bookmark) in exampleBookmarks.enumerated() {
                if let url = URL(string: bookmark.url) {
                    let newBookmark = Bookmark(url: url, title: bookmark.title)
                    newBookmark.sortIndex = index
                    modelContext.insert(newBookmark)
                }
            }

            // Example Presets (inserted in reverse order so they appear in desired order)

            // Dev - 4x4 grid (premium showcase)
            let devPreset = Preset(
                name: "Dev",
                rows: 4,
                cols: 4,
                urls: [
                    "https://github.com",
                    "https://stackoverflow.com",
                    "https://developer.apple.com",
                    "https://docs.swift.org",
                    "https://www.hackingwithswift.com",
                    "https://swiftui.directory",
                    "https://www.swift.org/blog",
                    "https://forums.swift.org",
                    "https://nshipster.com",
                    "https://www.objc.io",
                    "https://www.raywenderlich.com",
                    "https://www.swiftbysundell.com",
                    "https://developer.apple.com/documentation/swiftui",
                    "https://developer.apple.com/design/human-interface-guidelines",
                    "https://testflight.apple.com",
                    "https://appstoreconnect.apple.com"
                ]
            )
            modelContext.insert(devPreset)

            // News - 1x4 grid (horizontal strip)
            let newsPreset = Preset(
                name: "News",
                rows: 1,
                cols: 4,
                urls: [
                    "https://www.reuters.com",
                    "https://www.bbc.com/news",
                    "https://www.npr.org",
                    "https://apnews.com"
                ]
            )
            modelContext.insert(newsPreset)

            // Study - 2x2 grid
            let studyPreset = Preset(
                name: "Study",
                rows: 2,
                cols: 2,
                urls: [
                    "https://www.wikipedia.org",
                    "https://www.khanacademy.org",
                    "https://www.wolframalpha.com",
                    "https://scholar.google.com"
                ]
            )
            modelContext.insert(studyPreset)

            // Space - 2x3 grid
            let spacePreset = Preset(
                name: "Space",
                rows: 2,
                cols: 3,
                urls: [
                    "https://www.nasa.gov",
                    "https://www.spacex.com",
                    "https://www.space.com",
                    "https://www.esa.int",
                    "https://hubblesite.org",
                    "https://www.planetary.org"
                ]
            )
            modelContext.insert(spacePreset)

            // Stocks - 2x2 grid (1 news + 3 stock charts)
            let stocksPreset = Preset(
                name: "Stocks",
                rows: 2,
                cols: 2,
                urls: [
                    "https://www.cnbc.com/markets",
                    "https://finance.yahoo.com/chart/AAPL",
                    "https://finance.yahoo.com/chart/GOOGL",
                    "https://finance.yahoo.com/chart/MSFT"
                ]
            )
            modelContext.insert(stocksPreset)

            try modelContext.save()
            coordinator.errorHandler.showToast("Added example data")
        } catch {
            coordinator.errorHandler.showDataError("Failed to add example data: \(error.localizedDescription)")
        }
    }
    #endif
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
