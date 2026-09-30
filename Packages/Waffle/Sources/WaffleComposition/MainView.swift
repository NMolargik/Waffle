//
//  MainView.swift
//  WaffleComposition
//
//  The one browsing window: sidebar + grid + toolbar. Owns the sidebar view model
//  (from the session factory) and wires every feature view to the session's gated
//  actions and use-cases.
//

#if os(iOS)
import SwiftUI
import WebKit
import WaffleCore
import WaffleDesignSystem
import WaffleFeatureGrid
import WaffleFeatureSidebar
import WaffleFeatureSettings
import WaffleFeatureSyrup

public struct MainView: View {
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow
    @Environment(\.scenePhase) private var scenePhase

    private let session: SessionController
    @State private var sidebarModel: SidebarModel

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
    /// While the address bar has focus it takes the whole toolbar; every
    /// other control hides until editing ends.
    @State private var isEditingAddress = false

    public init(session: SessionController) {
        self.session = session
        _sidebarModel = State(initialValue: session.makeSidebarModel())
    }

    private var searchProvider: SearchProvider {
        SearchProvider(rawValue: searchProviderRawValue) ?? .google
    }

    private var grid: GridModel { session.grid }

    public var body: some View {
        @Bindable var session = session

        NavigationSplitView {
            SidebarView(
                model: sidebarModel,
                applyPreset: { self.session.applyPreset($0) },
                applyBookmark: { grid.loadInSelectedCell($0) },
                currentGrid: { (rows: grid.rowCount, cols: grid.colCount, urls: grid.flattenedAddresses()) },
                currentCell: {
                    guard let cell = grid.selectedCell, !cell.address.isEmpty else { return nil }
                    return (address: cell.address, title: cell.page.title)
                },
                isSyrupEnabled: session.isSyrupEnabled,
                canMakePresets: session.canMakePresets,
                requestSyrup: { self.session.requestSyrup() }
            )
            .navigationTitle(Text(verbatim: "Waffle"))
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
                model: grid,
                requestPopBack: popBack,
                fullscreenCell: gridReleasedCell
            )
            .padding(.horizontal, 10)
            .padding(.bottom, 10)
            .ignoresSafeArea(edges: .bottom)
            .background(Color.wafflePrimary.opacity(0.3))
            .toolbarTitleDisplayMode(.inline)
            .animation(.snappy, value: grid.poppedCell)
            .animation(.snappy, value: grid.selectedCell)
            .onAppear {
                if !grid.restoreFromSnapshotIfAvailable() {
                    grid.makeInitialItem()
                }
            }
            .onGeometryChange(for: CGFloat.self) { proxy in
                proxy.size.width
            } action: { newWidth in
                detailWidth = newWidth
            }
            .overlay {
                if let fullScreenCell {
                    FullScreenCellView(model: grid, cell: fullScreenCell)
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
                    grid.persistNow()
                }
            }
            .sheet(isPresented: $session.presentSyrupSheet) {
                SyrupView(
                    store: session.store,
                    onPurchased: { self.session.presentSyrupSheet = false },
                    onClose: { self.session.presentSyrupSheet = false }
                )
                .frame(minWidth: 420, minHeight: 520)
            }
            .sheet(isPresented: $showSettingsSheet) {
                SettingsView(
                    model: session.makeSettingsModel(),
                    isSyrupEnabled: session.isSyrupEnabled,
                    requestSyrup: { self.session.requestSyrup() },
                    openInApp: { grid.loadInSelectedCell($0) }
                )
            }
            .sheet(isPresented: $showRearrangeSheet) {
                RearrangeWaffleView(
                    rows: grid.rowCount,
                    cols: grid.colCount,
                    initialCells: grid.rearrangeCells(),
                    onCancel: { showRearrangeSheet = false },
                    onSave: { newOrder in
                        grid.applyReorderedURLs(newOrder)
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
            isActive: !(grid.selectedCell?.address.isEmpty ?? true)
        ) { activity in
            guard let cell = grid.selectedCell, let url = URL(string: cell.address) else { return }
            activity.title = cell.page.title.isEmpty ? cell.address : cell.page.title
            activity.webpageURL = url
            activity.isEligibleForHandoff = true
            activity.isEligibleForSearch = true
            self.session.annotateBrowsingActivity(activity, forAddress: cell.address)
        }
        .task {
            // Keep the sidebar current with writes from intents and CloudKit imports.
            for await _ in self.session.observeLibraryChanges() {
                sidebarModel.load()
            }
        }
        .toast(message: session.errorHandler.toastMessage) {
            self.session.errorHandler.dismissToast()
        }
        .errorAlert(Binding(
            get: { self.session.errorHandler.currentError },
            set: { _ in self.session.errorHandler.dismiss() }
        ))
    }

    // MARK: - Toolbar

    // Visibility priorities decide which items fold into the system More
    // menu first as the window narrows: fullscreen collapses first, then
    // pop out, then the automatic items — the address bar never collapses.

    @ToolbarContentBuilder
    private var navigationToolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .topBarLeading) {
            if !isEditingAddress {
                Button(String(localized: "Back"), systemImage: "chevron.backward") {
                    grid.selectedCell?.goBack()
                }
                .keyboardShortcut("[", modifiers: .command)
                .accessibilityHint(Text("Goes back in the selected cell"))

                Button(String(localized: "Forward"), systemImage: "chevron.forward") {
                    grid.selectedCell?.goForward()
                }
                .keyboardShortcut("]", modifiers: .command)
                .accessibilityHint(Text("Goes forward in the selected cell"))
            }
        }
    }

    @ToolbarContentBuilder
    private var addressToolbar: some ToolbarContent {
        @Bindable var grid = grid
        ToolbarItem(placement: .principal) {
            HStack(spacing: 8) {
                if !isEditingAddress {
                    Button {
                        grid.selectedCell?.reloadCell()
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
                    .transition(.scale.combined(with: .opacity))
                }

                AddressBarView(
                    text: $grid.addressText,
                    placeholder: String(localized: "Search or enter a URL"),
                    availableWidth: detailWidth,
                    onSubmit: { grid.submitAddress(using: searchProvider) },
                    onEditingChanged: { editing in
                        withAnimation(.snappy) { isEditingAddress = editing }
                    }
                )
            }
        }
        .visibilityPriority(.high)
    }

    @ToolbarContentBuilder
    private var trailingToolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            if !isEditingAddress, grid.rowCount > 1 || grid.colCount > 1 {
                fullscreenButton
            }
        }
        .visibilityPriority(ToolbarItemVisibilityPriority(lowerThan: .low))

        ToolbarItem(placement: .topBarTrailing) {
            if !isEditingAddress, (grid.rowCount > 1 || grid.colCount > 1) && fullScreenCell == nil {
                popOutButton
            }
        }
        .visibilityPriority(.low)

        ToolbarItem(placement: .topBarTrailing) {
            if !isEditingAddress, fullScreenCell == nil {
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
            if session.canUseFullscreen {
                toggleFullscreen()
            } else {
                session.requestSyrup()
            }
        }
        .keyboardShortcut("f", modifiers: [.command, .shift])
        .accessibilityLabel(fullScreenCell == nil ? Text("Enter fullscreen") : Text("Exit fullscreen"))
        .accessibilityHint(Text("Shows the selected cell by itself"))
    }

    private var popOutButton: some View {
        Button(
            grid.poppedCell != nil ? String(localized: "Pop Back") : String(localized: "Pop Out"),
            systemImage: grid.poppedCell != nil ? "rectangle.on.rectangle.slash" : "rectangle.on.rectangle"
        ) {
            if grid.poppedCell != nil {
                popBack()
                return
            }

            guard session.canUsePopout else {
                session.requestSyrup()
                return
            }
            if let cell = grid.selectedCell, !grid.isPoppedOut(cell) {
                grid.popOut(cell)
                openWindow(id: "DetachedWaffleCell", value: cell)
            }
        }
        .keyboardShortcut("p", modifiers: [.command, .shift])
        .disabled(grid.poppedCell == nil && grid.selectedCell == nil)
        .accessibilityHint(Text("Moves the selected cell into its own window"))
    }

    private var gridMenu: some View {
        Menu {
            Button {
                session.setGridSize(rows: grid.rowCount + 1, cols: grid.colCount)
            } label: {
                Label(String(localized: "Add Row"), systemImage: "rectangle.split.1x2.fill")
            }
            .disabled(grid.rowCount >= session.maxRows)

            Button {
                session.setGridSize(rows: grid.rowCount - 1, cols: grid.colCount)
            } label: {
                Label(String(localized: "Subtract Row"), systemImage: "rectangle.split.1x2")
            }
            .disabled(grid.rowCount <= 1)

            Divider()

            Button {
                session.setGridSize(rows: grid.rowCount, cols: grid.colCount + 1)
            } label: {
                Label(String(localized: "Add Column"), systemImage: "square.split.2x1.fill")
            }
            .disabled(grid.colCount >= session.maxCols)

            Button {
                session.setGridSize(rows: grid.rowCount, cols: grid.colCount - 1)
            } label: {
                Label(String(localized: "Subtract Column"), systemImage: "square.split.2x1")
            }
            .disabled(grid.colCount <= 1)

            Divider()

            Button(String(localized: "Rearrange"), systemImage: "arrow.left.arrow.right.square") {
                guard session.canUseRearrange else {
                    session.requestSyrup()
                    return
                }
                if grid.waffleRows.isEmpty {
                    grid.makeInitialItem()
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
            guard let cell = grid.selectedCell else { return }
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
        grid.popBack(poppedCellAddress: poppedCellAddress)
        dismissWindow(id: "DetachedWaffleCell")
    }
}
#endif
