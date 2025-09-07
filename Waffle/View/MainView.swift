//
//  MainView.swift
//  Waffle
//
//  Created by Nick Molargik on 9/2/25.
//

import SwiftUI
import WebKit
import SwiftData

struct MainView: View {
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Environment(WaffleCoordinator.self) private var coordinator
    
    @AppStorage("poppedCellAddress") private var poppedCellAddress: String = ""
    @AppStorage("lastGridSnapshot") private var lastGridSnapshotData: Data = Data()
    @AppStorage("searchProvider") private var searchProviderRawValue: String = SearchProvider.google.rawValue
    
    @State private var viewModel: MainView.ViewModel = MainView.ViewModel()
    
    private var searchProvider: SearchProvider {
        get { SearchProvider(rawValue: searchProviderRawValue) ?? .google }
        set { searchProviderRawValue = newValue.rawValue }
    }

    var body: some View {
        NavigationSplitView {
            SidebarView(
                applyPreset: { preset in
                    if !coordinator.canMakePresets && !coordinator.isSyrupEnabled {
                        coordinator.requestSyrup()
                        viewModel.showSyrupSheet = true
                        return
                    }
                    _ = viewModel.applyPreset(preset)
                    persistGridSnapshot()
                },
                savePreset: { providedName in
                    guard coordinator.canMakePresets else {
                        coordinator.requestSyrup()
                        viewModel.showSyrupSheet = true
                        return
                    }
                    viewModel.saveCurrentGridAsPreset(withName: providedName, modelContext: modelContext)
                    persistGridSnapshot()
                },
                applyBookmark: { bookmark in
                    viewModel.applyBookmark(bookmark)
                    persistGridSnapshot()
                },
                saveBookmark: { urlString, providedTitle in
                    viewModel.saveCurrentCellAsBookmark(urlString: urlString, title: providedTitle, modelContext: modelContext)
                },
                overwritePreset: { preset in
                    guard coordinator.canMakePresets else {
                        coordinator.requestSyrup()
                        viewModel.showSyrupSheet = true
                        return
                    }
                    viewModel.overwritePresetWithCurrentGrid(preset, modelContext: modelContext)
                    persistGridSnapshot()
                }
            )
            .navigationTitle("Waffle")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Settings", systemImage: "gearshape.fill") {
                        viewModel.showSettingsSheet.toggle()
                    }
                }
            }
        } detail: {
            Color.clear
                .frame(height: 0)
            
            @Bindable var coord = coordinator
            WaffleGridView(
                waffleState: $coord.waffleState,
                addressBarString: $viewModel.addressBarString,
                requestPopBack: {
                    viewModel.initiatePopBack(poppedCellAddress: poppedCellAddress) {
                        dismissWindow(id: "DetachedWaffleCell")
                    }
                    persistGridSnapshot()
                },
                fullscreenCell: viewModel.fullScreenCell,
                copyToSelectedCell: { address in
                    coord.waffleState.selectedCell?.loadURL(urlString: address)
                }
            )
            .padding(.horizontal, 4)
            .background(Color(white: 0.9))
            .onAppear(perform: coordinator.waffleState.makeInitialItem)
            .toolbarTitleDisplayMode(.inline)
            .animation(.snappy, value: coordinator.waffleState.poppedCell)
            .animation(.snappy, value: coordinator.waffleState.selectedCell)
            .ignoresSafeArea()
            // Persist when any cell URLs change
            .onChange(of: coordinator.waffleState.flattenedAddresses()) { _, _ in
                persistGridSnapshot()
            }
            // Persist when the structural identity of cells changes (rows/cols adjustments)
            .onChange(of: coordinator.waffleState.waffleRows.map { $0.map(\.id) }) { _, _ in
                persistGridSnapshot()
            }
            .onAppear {
                viewModel.configure(coordinator: coordinator)
                restoreGridSnapshotIfAvailable()
                persistGridSnapshot()
            }
            .overlay {
                if let fullScreenWaffleCell = viewModel.fullScreenCell {
                    FullScreenCellView(viewModel: $viewModel, cell: fullScreenWaffleCell)
                }
            }
            .toolbar {
                ToolbarItemGroup(placement: .topBarLeading) {
                    Button("Back", systemImage: "chevron.backward") {
                        viewModel.goBack()
                        persistGridSnapshot()
                    }
                    
                    Button("Forward", systemImage: "chevron.forward") {
                        viewModel.goForward()
                        persistGridSnapshot()
                    }
                }
                ToolbarItem(placement: .principal) {
                    HStack {
                        TextField("Search or enter a URL", text: $viewModel.addressBarString)
                            .padding(10)
                            .frame(idealWidth: 350)
                            .glassEffect(.regular, in: .capsule)
                            .textContentType(.URL)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .onSubmit {
                                viewModel.submitAddress(using: searchProvider)
                                persistGridSnapshot()
                            }
                        Button {
                            viewModel.reloadSelected()
                            persistGridSnapshot()
                        } label: {
                            Image(systemName: "arrow.clockwise")
                                .frame(maxHeight: .infinity)
                        }
                        .buttonStyle(.glass)
                    }
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    if (coordinator.waffleState.rowCount > 1 || coordinator.waffleState.colCount > 1) {
                        Button {
                            if coordinator.canUseFullscreen {
                                viewModel.toggleFullscreen(cell: coordinator.waffleState.selectedCell)
                            } else {
                                coordinator.requestSyrup()
                                viewModel.showSyrupSheet = true
                            }
                            persistGridSnapshot()
                        } label: {
                            if viewModel.fullScreenCell != nil {
                                HStack {
                                    Text("Minimize")
                                    
                                    Image(systemName: "arrow.down.right.and.arrow.up.left.rectangle")
                                }
                            } else {
                                Image(systemName: "arrow.up.left.and.arrow.down.right.rectangle")
                            }
                        }
                        
                        if (viewModel.fullScreenCell == nil) {
                            Button(coordinator.waffleState.poppedCell != nil ? "Pop Back" : "Pop Out", systemImage: coordinator.waffleState.poppedCell != nil ? "rectangle.on.rectangle.slash" : "rectangle.on.rectangle") {
                                if viewModel.canUsePopout() {
                                    viewModel.popOutSelectedCell { cell in
                                        openWindow(id: "DetachedWaffleCell", value: cell)
                                    }
                                    persistGridSnapshot()
                                } else {
                                    coordinator.requestSyrup()
                                    viewModel.showSyrupSheet = true
                                }
                            }
                            .disabled(!coordinator.waffleState.canPopOut)
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    @Bindable var coord = coordinator
                    if (viewModel.fullScreenCell == nil) {
                        Menu {
                            Stepper(
                                value: Binding(
                                    get: { coord.waffleState.rowCount },
                                    set: { newValue in
                                        viewModel.setRows(newValue)
                                        persistGridSnapshot()
                                    }
                                ),
                                in: 1...4
                            ) {
                                Label("Rows: \(coordinator.waffleState.rowCount)", systemImage: "rectangle.split.1x2")
                                    .padding(.leading, 5)
                            }
                            Stepper(
                                value: Binding(
                                    get: { coord.waffleState.colCount },
                                    set: { newValue in
                                        viewModel.setCols(newValue)
                                        persistGridSnapshot()
                                    }
                                ),
                                in: 1...4
                            ) {
                                Label("Columns: \(coordinator.waffleState.colCount)", systemImage: "rectangle.split.2x1")
                            }
                            Button("Rearrange", systemImage: "arrow.left.arrow.right.square") {
                                guard coordinator.canUseRearrange else {
                                    coordinator.requestSyrup()
                                    viewModel.showSyrupSheet = true
                                    return
                                }
                                if coordinator.waffleState.waffleRows.isEmpty {
                                    coordinator.waffleState.makeInitialItem()
                                }
                                DispatchQueue.main.async {
                                    let current = coordinator.waffleState.flattenedAddresses()
                                    
                                    viewModel.pendingReorderedURLs = current.isEmpty ? ["https://apple.com"] : current
                                    viewModel.showRearrangeSheet = true
                                }
                            }
                        } label: {
                            Image(systemName: "square.grid.3x3.fill")
                                .foregroundStyle(
                                    Color.waffleSecondary
                                )
                        }
                    }
                }
            }
            .toolbarTitleDisplayMode(.inline)
            .onChange(of: coordinator.presentSyrupSheet) { _, newValue in
                if newValue {
                    viewModel.showSyrupSheet = true
                }
            }
            .onChange(of: coordinator.waffleState.selectedCell?.id) { _, _ in
                persistGridSnapshot()
            }
            .onChange(of: coordinator.waffleState.rowCount) { _, _ in
                persistGridSnapshot()
            }
            .onChange(of: coordinator.waffleState.colCount) { _, _ in
                persistGridSnapshot()
            }
            .onChange(of: scenePhase) { _, newPhase in
                // Extra safety: persist on lifecycle changes
                if newPhase == .inactive || newPhase == .background {
                    persistGridSnapshot()
                }
            }
            .sheet(isPresented: $viewModel.showSyrupSheet, onDismiss: {
                coordinator.presentSyrupSheet = false
            }) {
                SyrupView(
                    onPurchased: {
                        viewModel.showSyrupSheet = false
                        coordinator.presentSyrupSheet = false
                    },
                    onClose: {
                        viewModel.showSyrupSheet = false
                        coordinator.presentSyrupSheet = false
                    }
                )
                .frame(minWidth: 420, minHeight: 520)
            }
            .sheet(isPresented: $viewModel.showSettingsSheet) { SettingsView() }
            .sheet(isPresented: $viewModel.showRearrangeSheet) {
                RearrangeWaffleView(
                    urls: viewModel.pendingReorderedURLs,
                    rows: coordinator.waffleState.rowCount,
                    cols: coordinator.waffleState.colCount,
                    onCancel: {
                        viewModel.showRearrangeSheet = false
                    },
                    onSave: { newOrder in
                        viewModel.applyReorderedURLs(newOrder)
                        persistGridSnapshot()
                        viewModel.showRearrangeSheet = false
                    }
                )
                .id(viewModel.pendingReorderedURLs)
                .onAppear {
                    let live = coordinator.waffleState.flattenedAddresses()
                    if live.count != viewModel.pendingReorderedURLs.count || viewModel.pendingReorderedURLs.isEmpty {
                        viewModel.pendingReorderedURLs = live.isEmpty ? ["https://apple.com"] : live
                    }
                }
                .frame(minWidth: 500, minHeight: 400)
            }
        }
    }

    private func persistGridSnapshot() {
        let snapshot = coordinator.waffleState.makeSnapshot()
        if let data = try? JSONEncoder().encode(snapshot) {
            lastGridSnapshotData = data
        }
    }
    
    private func restoreGridSnapshotIfAvailable() {
        guard !lastGridSnapshotData.isEmpty,
              let snapshot = try? JSONDecoder().decode(WaffleState.Snapshot.self, from: lastGridSnapshotData) else {
            return
        }
        coordinator.waffleState.apply(snapshot: snapshot)
        // Update address bar to selected cell’s address if available
        if let sel = coordinator.waffleState.selectedCell {
            viewModel.addressBarString = sel.address
        }
    }
}

#Preview {
    // In-memory SwiftData container for Preset and Bookmark
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Bookmark.self, Preset.self, configurations: config)

    // Coordinator + Store for environment
    let storeManager = StoreManager()
    let coordinator = WaffleCoordinator(store: storeManager)

    // Seed a simple initial grid for nicer preview
    coordinator.waffleState.rowCount = 2
    coordinator.waffleState.colCount = 2
    coordinator.waffleState.waffleRows = (0..<2).map { _ in
        (0..<2).map { _ in
            let cell = WaffleCell()
            cell.address = "https://apple.com"
            return cell
        }
    }
    coordinator.waffleState.selectedCell = coordinator.waffleState.waffleRows.first?.first

    // AppStorage defaults for preview run
    UserDefaults.standard.register(defaults: [
        "poppedCellAddress": "https://apple.com",
        "lastGridSnapshot": Data(),
        "searchProvider": SearchProvider.google.rawValue
    ])

    return MainView()
        .modelContainer(container)
        .environment(coordinator)
}
