//
//  MainView.swift
//  Waffle
//
//  Created by Nick Molargik on 9/2/25.
//

import AppIntents
import SwiftUI
import WebKit
import SwiftData

struct MainView: View {
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow
    @Environment(\.scenePhase) private var scenePhase
    @Environment(WaffleCoordinator.self) private var coordinator

    @AppStorage("poppedCellAddress") private var poppedCellAddress: String = ""
    @AppStorage("searchProvider") private var searchProviderRawValue: String = SearchProvider.google.rawValue

    @State private var showSettingsSheet = false
    @State private var showRearrangeSheet = false
    /// Drives the fullscreen overlay's WebView.
    @State private var fullScreenCell: WaffleCell? = nil
    /// Blanks the cell's grid slot. Set before `fullScreenCell` on entry and
    /// cleared after it on exit, so the shared WebPage is never hosted by the
    /// grid's WebView and the overlay's WebView at the same time.
    @State private var gridReleasedCell: WaffleCell? = nil
    @State private var fullscreenTransitionTask: Task<Void, Never>? = nil
    /// Width of the detail column, measured so the address bar can fill it.
    @State private var detailWidth: CGFloat = 0

    private var searchProvider: SearchProvider {
        SearchProvider(rawValue: searchProviderRawValue) ?? .google
    }

    private var waffleState: WaffleState { coordinator.waffleState }

    var body: some View {
        @Bindable var coord = coordinator

        NavigationSplitView {
            SidebarView()
                .navigationTitle(Text("Waffle"))
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button(String(localized: "Settings"), systemImage: "gearshape.fill") {
                            showSettingsSheet.toggle()
                        }
                        .accessibilityHint(Text("Opens app settings"))
                    }
                }
        } detail: {
            WaffleGridView(
                waffleState: waffleState,
                requestPopBack: popBack,
                fullscreenCell: gridReleasedCell
            )
            .padding(.horizontal, 10)
            .padding(.bottom, 10)
            .ignoresSafeArea(edges: .bottom)
            .background(Color.wafflePrimary.opacity(0.3))
            .toolbarTitleDisplayMode(.inline)
            .animation(.snappy, value: waffleState.poppedCell)
            .animation(.snappy, value: waffleState.selectedCell)
            .onAppear {
                if !waffleState.restoreFromSnapshotIfAvailable() {
                    waffleState.makeInitialItem()
                }
            }
            .onGeometryChange(for: CGFloat.self) { proxy in
                proxy.size.width
            } action: { newWidth in
                detailWidth = newWidth
            }
            .overlay {
                if let fullScreenCell {
                    FullScreenCellView(cell: fullScreenCell)
                }
            }
            .toolbar {
                navigationToolbar
                addressToolbar
                trailingToolbar
            }
            .onChange(of: scenePhase) { _, newPhase in
                // Persist immediately on lifecycle changes (no debounce).
                if newPhase == .inactive || newPhase == .background {
                    waffleState.persistNow()
                }
            }
            .sheet(isPresented: $coord.presentSyrupSheet) {
                SyrupView(
                    onPurchased: { coordinator.presentSyrupSheet = false },
                    onClose: { coordinator.presentSyrupSheet = false }
                )
                .frame(minWidth: 420, minHeight: 520)
            }
            .sheet(isPresented: $showSettingsSheet) { SettingsView() }
            .sheet(isPresented: $showRearrangeSheet) {
                RearrangeWaffleView(
                    rows: waffleState.rowCount,
                    cols: waffleState.colCount,
                    onCancel: { showRearrangeSheet = false },
                    onSave: { newOrder in
                        waffleState.applyReorderedURLs(newOrder)
                        showRearrangeSheet = false
                    }
                )
            }
        }
        // Surface the page being browsed to the system: Handoff, and Siri's
        // on-screen awareness via the app-entity annotation when the page
        // matches a saved bookmark.
        .userActivity(
            "com.molargiksoftware.Waffle.browsing",
            isActive: !(waffleState.selectedCell?.address.isEmpty ?? true)
        ) { activity in
            guard let cell = waffleState.selectedCell, let url = URL(string: cell.address) else { return }
            activity.title = cell.page.title.isEmpty ? cell.address : cell.page.title
            activity.webpageURL = url
            activity.isEligibleForHandoff = true
            activity.isEligibleForSearch = true
            if let bookmark = coordinator.library.bookmarks().first(where: { $0.urlString == cell.address }) {
                activity.appEntityIdentifier = EntityIdentifier(for: BookmarkEntity.self, identifier: bookmark.id)
            }
        }
        .toast(message: coordinator.errorHandler.toastMessage) {
            coordinator.errorHandler.dismissToast()
        }
        .errorAlert(Binding(
            get: { coordinator.errorHandler.currentError },
            set: { _ in coordinator.errorHandler.dismiss() }
        ))
    }

    // MARK: - Toolbar

    // Visibility priorities decide which items fold into the system More
    // menu first as the window narrows: fullscreen collapses first, then
    // pop out, then the automatic items — the address bar never collapses.

    @ToolbarContentBuilder
    private var navigationToolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .topBarLeading) {
            Button(String(localized: "Back"), systemImage: "chevron.backward") {
                waffleState.selectedCell?.goBack()
            }
            .keyboardShortcut("[", modifiers: .command)
            .accessibilityHint(Text("Goes back in the selected cell"))

            Button(String(localized: "Forward"), systemImage: "chevron.forward") {
                waffleState.selectedCell?.goForward()
            }
            .keyboardShortcut("]", modifiers: .command)
            .accessibilityHint(Text("Goes forward in the selected cell"))
        }
    }

    @ToolbarContentBuilder
    private var addressToolbar: some ToolbarContent {
        @Bindable var state = coordinator.waffleState
        ToolbarItem(placement: .principal) {
            HStack(spacing: 8) {
                Button {
                    waffleState.selectedCell?.reloadCell()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .frame(
                            width: AppConfiguration.barControlHeight,
                            height: AppConfiguration.barControlHeight
                        )
                        .contentShape(Circle())
                }
                .keyboardShortcut("r", modifiers: .command)
                .buttonStyle(.plain)
                .glassEffect(.regular.interactive(), in: .circle)
                .accessibilityLabel(Text("Reload"))
                .accessibilityHint(Text("Reloads the selected cell"))

                AddressBarView(
                    text: $state.addressText,
                    placeholder: String(localized: "Search or enter a URL"),
                    availableWidth: detailWidth,
                    onSubmit: { waffleState.submitAddress(using: searchProvider) }
                )
            }
        }
        .visibilityPriority(.high)
    }

    @ToolbarContentBuilder
    private var trailingToolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            if waffleState.rowCount > 1 || waffleState.colCount > 1 {
                fullscreenButton
            }
        }
        .visibilityPriority(ToolbarItemVisibilityPriority(lowerThan: .low))

        ToolbarItem(placement: .topBarTrailing) {
            if (waffleState.rowCount > 1 || waffleState.colCount > 1) && fullScreenCell == nil {
                popOutButton
            }
        }
        .visibilityPriority(.low)

        ToolbarItem(placement: .topBarTrailing) {
            if fullScreenCell == nil {
                gridMenu
            }
        }
    }

    private var fullscreenButton: some View {
        Button(
            fullScreenCell == nil ? String(localized: "Fullscreen") : String(localized: "Minimize"),
            systemImage: fullScreenCell == nil
                ? "arrow.up.left.and.arrow.down.right.rectangle"
                : "arrow.down.right.and.arrow.up.left.rectangle"
        ) {
            if coordinator.canUseFullscreen {
                toggleFullscreen()
            } else {
                coordinator.requestSyrup()
            }
        }
        .keyboardShortcut("f", modifiers: [.command, .shift])
        .accessibilityLabel(fullScreenCell == nil ? Text("Enter fullscreen") : Text("Exit fullscreen"))
        .accessibilityHint(Text("Shows the selected cell by itself"))
    }

    private var popOutButton: some View {
        Button(
            waffleState.poppedCell != nil ? String(localized: "Pop Back") : String(localized: "Pop Out"),
            systemImage: waffleState.poppedCell != nil ? "rectangle.on.rectangle.slash" : "rectangle.on.rectangle"
        ) {
            if waffleState.poppedCell != nil {
                popBack()
                return
            }

            guard coordinator.canUsePopout else {
                coordinator.requestSyrup()
                return
            }
            if let cell = waffleState.selectedCell, !waffleState.isPoppedOut(cell) {
                waffleState.popOut(cell)
                openWindow(id: "DetachedWaffleCell", value: cell)
            }
        }
        .keyboardShortcut("p", modifiers: [.command, .shift])
        .disabled(waffleState.poppedCell == nil && waffleState.selectedCell == nil)
        .accessibilityHint(Text("Moves the selected cell into its own window"))
    }

    private var gridMenu: some View {
        Menu {
            Button {
                coordinator.setGridSize(rows: waffleState.rowCount + 1, cols: waffleState.colCount)
            } label: {
                Label(String(localized: "Add Row"), systemImage: "rectangle.split.1x2.fill")
            }
            .disabled(waffleState.rowCount >= coordinator.maxRows)

            Button {
                coordinator.setGridSize(rows: waffleState.rowCount - 1, cols: waffleState.colCount)
            } label: {
                Label(String(localized: "Subtract Row"), systemImage: "rectangle.split.1x2")
            }
            .disabled(waffleState.rowCount <= 1)

            Divider()

            Button {
                coordinator.setGridSize(rows: waffleState.rowCount, cols: waffleState.colCount + 1)
            } label: {
                Label(String(localized: "Add Column"), systemImage: "square.split.2x1.fill")
            }
            .disabled(waffleState.colCount >= coordinator.maxCols)

            Button {
                coordinator.setGridSize(rows: waffleState.rowCount, cols: waffleState.colCount - 1)
            } label: {
                Label(String(localized: "Subtract Column"), systemImage: "square.split.2x1")
            }
            .disabled(waffleState.colCount <= 1)

            Divider()

            Button(String(localized: "Rearrange"), systemImage: "arrow.left.arrow.right.square") {
                guard coordinator.canUseRearrange else {
                    coordinator.requestSyrup()
                    return
                }
                if waffleState.waffleRows.isEmpty {
                    waffleState.makeInitialItem()
                }
                showRearrangeSheet = true
            }
        } label: {
            Image(systemName: "square.grid.3x3.fill")
        }
        .accessibilityLabel(Text("Grid options"))
        .accessibilityHint(Text("Add or remove rows and columns, or rearrange cells"))
    }

    // MARK: - Actions

    private func toggleFullscreen() {
        // Ignore presses while a transition is settling — re-hosting the
        // WebPage mid-teardown is exactly the race that crashes WebKit.
        if fullScreenCell == nil, gridReleasedCell != nil { return }

        fullscreenTransitionTask?.cancel()
        if fullScreenCell == nil {
            guard let cell = waffleState.selectedCell else { return }
            // Two-phase entry: blank the grid slot first so its WebView is
            // fully torn down before the overlay hosts the same WebPage.
            gridReleasedCell = cell
            fullscreenTransitionTask = Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(100))
                guard !Task.isCancelled else { return }
                fullScreenCell = cell
            }
        } else {
            // Reverse on exit: drop the overlay's WebView first, then restore
            // the grid slot once teardown has settled.
            fullScreenCell = nil
            fullscreenTransitionTask = Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(150))
                guard !Task.isCancelled else { return }
                gridReleasedCell = nil
            }
        }
    }

    private func popBack() {
        waffleState.popBack(poppedCellAddress: poppedCellAddress)
        dismissWindow(id: "DetachedWaffleCell")
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Bookmark.self, Preset.self, configurations: config)

    let errorHandler = ErrorHandler()
    let store = StoreManager()
    let library = LibraryManager(container: container, errorHandler: errorHandler)
    let state = WaffleState()
    let coordinator = WaffleCoordinator(store: store, library: library, errorHandler: errorHandler, waffleState: state)

    state.rowCount = 2
    state.colCount = 2
    state.waffleRows = (0..<2).map { _ in
        (0..<2).map { _ in
            let cell = WaffleCell()
            cell.address = "https://apple.com"
            return cell
        }
    }
    state.selectedCell = state.waffleRows.first?.first

    return MainView()
        .modelContainer(container)
        .environment(coordinator)
        .environment(store)
}
