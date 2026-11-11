//
//  PhoneMainView.swift
//  WaffleComposition
//
//  The browsing window on iPhone and iPhone Duo. Instead of the iPad's rows x cols grid
//  it shows two to four resizable panes:
//
//  - compact width (every iPhone, and the Duo's outer display): up to two panes, stacked in
//    portrait and side by side in landscape, with a draggable divider.
//  - the Duo's inner display (regular/regular size classes): up to four panes, with a gutter
//    on the fold so no pane straddles it.
//  - half-folded laptop pose (Syrup): live panes on the upright half, controls on the flat half.
//
//  Layout is driven by size classes and the fold region, never by orientation or pose
//  checks, as Apple advises. Panes are never re-hosted when the layout changes, so a fold
//  transition does not reload pages.
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

public struct PhoneMainView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    private let session: SessionController
    @State private var sidebarModel: SidebarModel

    @AppStorage("searchProvider") private var searchProviderRawValue: String = SearchProvider.google.rawValue

    @State private var showSettingsSheet = false
    @State private var showLayoutsSheet = false
    /// The user maximized the selected pane.
    @State private var isMaximized = false
    /// The Duo was closed: its outer display shows the focused pane alone. Cleared on open,
    /// so the full arrangement returns exactly as it was.
    @State private var foldCollapsed = false
    @State private var isEditingAddress = false
    @State private var hinge: HingeSummary = .unknown

    public init(session: SessionController) {
        self.session = session
        _sidebarModel = State(initialValue: session.makeSidebarModel())
    }

    private var grid: GridModel { session.grid }

    private var searchProvider: SearchProvider {
        SearchProvider(rawValue: searchProviderRawValue) ?? .google
    }

    private var mode: PaneMode {
        PaneMode.resolve(
            horizontalRegular: horizontalSizeClass == .regular,
            verticalRegular: verticalSizeClass == .regular
        )
    }

    /// The pane shown alone, if any. Compact displays can't hold more than two panes, so
    /// a three- or four-pane arrangement (opened on the inner display) shows the focused pane.
    private var focusedPaneID: UUID? {
        guard grid.paneCount > 1 else { return nil }
        let forced = mode == .compact && (foldCollapsed || grid.paneCount > PaneLimits.maxCompactPanes)
        guard isMaximized || forced else { return nil }
        let index = PaneFrameCalculator.focusIndex(selected: grid.selectedPaneIndex, count: grid.paneCount)
        return grid.panes[index].id
    }

    private var effectiveHinge: HingeSummary {
        #if DEBUG
        if let simulated = DebugFoldSimulation.hinge { return simulated }
        #endif
        return hinge
    }

    // MARK: - Body

    public var body: some View {
        @Bindable var session = session

        GeometryReader { proxy in
            let reading = FoldSensing.reading(in: proxy)
            let laptopPose = mode == .inner
                && reading?.isActive == true
                && reading?.gutter.primaryIsHorizontal == false
                && (effectiveHinge == .partiallyOpen || effectiveHinge == .unknown)
            let isDesk = laptopPose && session.canUseDeskMode
            let layout = PhoneScreenLayout.compute(
                size: proxy.size,
                safe: (0, 0, 0, 0),
                fold: reading?.gutter,
                mode: mode,
                deskMode: isDesk,
                barOnFarSide: selectedPaneIsOnFarSide(primaryIsHorizontal: reading?.gutter.primaryIsHorizontal ?? (proxy.size.width >= proxy.size.height))
            )

            ZStack(alignment: .topLeading) {
                PaneWorkspaceView(
                    model: grid,
                    primaryIsHorizontal: layout.primaryIsHorizontal,
                    fold: layout.fold,
                    focusedPaneID: focusedPaneID
                )
                .frame(width: layout.workspace.width, height: layout.workspace.height)
                .offset(x: layout.workspace.minX, y: layout.workspace.minY)

                if let bar = layout.bar {
                    controlBar(width: bar.width)
                        .frame(width: bar.width, height: bar.height)
                        .offset(x: bar.minX, y: bar.minY)
                }

                if let deck = layout.deck {
                    DeskDeck(
                        session: session,
                        sidebarModel: sidebarModel,
                        mode: mode,
                        width: deck.width,
                        searchProvider: searchProvider,
                        isEditingAddress: $isEditingAddress,
                        openLayouts: { showLayoutsSheet = true },
                        openSettings: { showSettingsSheet = true }
                    )
                    .frame(width: deck.width, height: deck.height)
                    .offset(x: deck.minX, y: deck.minY)
                }

                if laptopPose, !session.canUseDeskMode, let bar = layout.bar {
                    deskModeOffer
                        .offset(x: bar.minX + 4, y: bar.minY - 52)
                }
            }
        }
        .background(Color.wafflePrimary.opacity(0.3).ignoresSafeArea())
        .observingHinge($hinge)
        .animation(.snappy, value: isEditingAddress)
        .onAppear {
            grid.contentBlocking.start()
            if !grid.restoreFromSnapshotIfAvailable() {
                grid.makeInitialItem()
            }
            session.adaptWorkspaceToEntitlement()
            session.configurePhoneAutoRefreshGate()
            #if DEBUG
            DebugPaneSeeding.applyIfRequested(to: grid)
            let defaults = UserDefaults.standard
            if defaults.bool(forKey: "WaffleDebugMaximize") { isMaximized = true }
            switch defaults.string(forKey: "WaffleDebugSheet") {
            case "layouts": showLayoutsSheet = true
            case "settings": showSettingsSheet = true
            default: break
            }
            if defaults.string(forKey: "WaffleDebugAction") == "addPane" {
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(1500))
                    session.addPane(mode: mode)
                }
            }
            #endif
        }
        .onChange(of: mode, initial: true) { old, new in
            // Closing the Duo: the outer display keeps the focused pane. Opening it again
            // restores the arrangement because nothing about it was changed or reloaded.
            if old == .inner && new == .compact {
                foldCollapsed = true
            } else if new == .inner {
                foldCollapsed = false
            }
        }
        .onChange(of: scenePhase, initial: true) { _, newPhase in
            if newPhase == .inactive || newPhase == .background {
                grid.persistNow()
            }
            grid.setAppActive(newPhase == .active)
        }
        .sheet(isPresented: $session.presentSyrupSheet) {
            SyrupView(
                store: session.store,
                onPurchased: { self.session.presentSyrupSheet = false },
                onClose: { self.session.presentSyrupSheet = false }
            )
        }
        .sheet(isPresented: $showSettingsSheet) {
            SettingsView(
                model: session.makeSettingsModel(),
                isSyrupEnabled: session.isSyrupEnabled,
                requestSyrup: { self.session.requestSyrup() },
                openInApp: { grid.loadInSelectedCell($0) },
                contentBlocking: ContentBlockingSettingsBinding(
                    isEnabled: Binding(
                        get: { grid.contentBlocking.isGloballyEnabled },
                        set: { grid.contentBlocking.isGloballyEnabled = $0 }
                    ),
                    exceptionHosts: grid.contentBlocking.exceptionHosts,
                    removeException: { grid.contentBlocking.removeException(host: $0) },
                    listTitles: grid.contentBlocking.listTitles
                )
            )
        }
        .sheet(isPresented: $showLayoutsSheet) { layoutsSheet }
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

    private func selectedPaneIsOnFarSide(primaryIsHorizontal: Bool) -> Bool {
        guard let index = grid.selectedPaneIndex else { return false }
        return PaneFrameCalculator.slots(count: grid.paneCount, primaryIsHorizontal: primaryIsHorizontal).b.contains(index)
    }

    // MARK: - Control bar

    private func controlBar(width: CGFloat) -> some View {
        @Bindable var grid = grid
        let showsMaximize = grid.paneCount > 1 && !(mode == .compact && grid.paneCount > PaneLimits.maxCompactPanes)
        let buttonCount = showsMaximize ? 4 : 3
        let reserved = CGFloat(buttonCount) * 44 + CGFloat(buttonCount) * 8 + 16

        return HStack(spacing: 8) {
            if !isEditingAddress {
                circleButton("Back", systemImage: "chevron.backward") { grid.selectedCell?.goBack() }
                    .opacity(grid.selectedCell?.canGoBack == true ? 1 : 0.45)
            }

            AddressBarView(
                text: $grid.addressText,
                placeholder: String(localized: "Search or enter a URL"),
                availableWidth: width,
                reservedControlWidth: reserved,
                onSubmit: { grid.submitAddress(using: searchProvider) },
                onEditingChanged: { editing in
                    withAnimation(.snappy) { isEditingAddress = editing }
                }
            )

            if !isEditingAddress {
                if showsMaximize {
                    circleButton(
                        focusedPaneID == nil ? "Maximize Pane" : "Show All Panes",
                        systemImage: focusedPaneID == nil
                            ? "arrow.up.left.and.arrow.down.right"
                            : "arrow.down.right.and.arrow.up.left"
                    ) { toggleMaximize() }
                }
                reloadButton
                menuButton
            }
        }
        .padding(.horizontal, 6)
    }

    private func circleButton(_ title: LocalizedStringKey, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .frame(width: AppConfiguration.barControlHeight, height: AppConfiguration.barControlHeight)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .circle)
        .accessibilityLabel(Text(title))
    }

    /// Tap reloads; touch and hold opens the pane's auto-refresh options.
    private var reloadButton: some View {
        Menu {
            autoRefreshItem
        } label: {
            Image(systemName: grid.selectedCell?.refreshInterval == .off || grid.selectedCell == nil
                  ? "arrow.clockwise" : "arrow.trianglehead.2.clockwise.rotate.90")
                .frame(width: AppConfiguration.barControlHeight, height: AppConfiguration.barControlHeight)
                .contentShape(Circle())
        } primaryAction: {
            grid.selectedCell?.reloadCell()
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .circle)
        .accessibilityLabel(Text("Reload"))
        .accessibilityHint(Text("Reloads the selected pane. Touch and hold for auto-refresh options"))
    }

    @ViewBuilder
    private var autoRefreshItem: some View {
        if let cell = grid.selectedCell {
            if session.canUsePaneAutoRefresh {
                AutoRefreshMenu(
                    selection: cell.refreshInterval,
                    onSelect: { grid.setRefreshInterval($0, for: cell) }
                )
            } else {
                Button { session.requestSyrup() } label: {
                    Label("Auto-Refresh", systemImage: "drop.fill")
                }
            }
        }
    }

    private var menuButton: some View {
        Menu {
            Section("Panes") {
                ForEach(Array(grid.panes.enumerated()), id: \.element.id) { index, pane in
                    Button {
                        grid.select(pane)
                    } label: {
                        Label(paneTitle(pane, index: index), systemImage: grid.selectedCell == pane ? "checkmark" : "rectangle")
                    }
                }
            }

            Button { session.addPane(mode: mode) } label: {
                Label("Add Pane", systemImage: "plus.rectangle.on.rectangle")
            }

            if grid.paneCount > 1, let selected = grid.selectedCell {
                Button(role: .destructive) { session.removePane(selected) } label: {
                    Label("Close Pane", systemImage: "xmark.rectangle")
                }
            }

            if grid.paneCount == 2 {
                Button { grid.swapPanes(0, 1) } label: {
                    Label("Swap Panes", systemImage: "arrow.left.arrow.right")
                }
            }

            Divider()

            Button { grid.selectedCell?.goForward() } label: {
                Label("Forward", systemImage: "chevron.forward")
            }
            .disabled(grid.selectedCell?.canGoForward != true)

            autoRefreshItem

            Divider()

            Button { showLayoutsSheet = true } label: {
                Label("Layouts & Bookmarks", systemImage: "rectangle.split.2x1")
            }
            Button { session.savePaneLayout() } label: {
                Label("Save Layout", systemImage: "square.and.arrow.down")
            }
            Button { showSettingsSheet = true } label: {
                Label("Settings", systemImage: "gearshape")
            }
        } label: {
            Image(systemName: "ellipsis")
                .frame(width: AppConfiguration.barControlHeight, height: AppConfiguration.barControlHeight)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .circle)
        .accessibilityLabel(Text("Panes and layouts"))
        .accessibilityHint(Text("Add or close panes, save layouts, and open settings"))
    }

    private func paneTitle(_ pane: WaffleCell, index: Int) -> String {
        if !pane.page.title.isEmpty { return pane.page.title }
        if !pane.address.isEmpty { return URLDisplayFormatter.compact(pane.address) }
        return String(localized: "Pane \(index + 1)")
    }

    private var deskModeOffer: some View {
        Button { session.requestSyrup() } label: {
            Label("Desk Mode", systemImage: "drop.fill")
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 14)
                .frame(minHeight: 44)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .capsule)
        .accessibilityHint(Text("Desk mode is part of Syrup"))
    }

    // MARK: - Layouts sheet

    private var layoutsSheet: some View {
        NavigationStack {
            SidebarView(
                model: sidebarModel,
                applyPreset: { preset in
                    session.applyPaneLayout(preset, mode: mode)
                    showLayoutsSheet = false
                },
                applyBookmark: { address in
                    grid.loadInSelectedCell(address)
                    showLayoutsSheet = false
                },
                currentGrid: {
                    let count = grid.paneCount
                    let shape = PaneLimits.gridShape(forPaneCount: count)
                    return (
                        rows: shape.rows, cols: shape.cols,
                        urls: grid.flattenedAddresses(),
                        refreshIntervals: grid.flattenedRefreshIntervals(),
                        paneCount: count,
                        paneRatios: grid.paneRatios.array
                    )
                },
                currentCell: {
                    guard let cell = grid.selectedCell, !cell.address.isEmpty else { return nil }
                    return (address: cell.address, title: cell.page.title)
                },
                isSyrupEnabled: session.isSyrupEnabled,
                canMakePresets: PaneLimits.canSaveLayout(existingCount: sidebarModel.presets.count, isSyrupEnabled: session.isSyrupEnabled),
                requestSyrup: {
                    // One sheet at a time: close this one, then show the paywall.
                    showLayoutsSheet = false
                    Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(450))
                        session.requestSyrup()
                    }
                },
                isPhoneLayouts: true
            )
            .navigationTitle(Text("Layouts & Bookmarks"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(String(localized: "Done")) { showLayoutsSheet = false }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    // MARK: - Actions

    private func toggleMaximize() {
        if focusedPaneID != nil {
            isMaximized = false
            if grid.paneCount <= PaneLimits.maxCompactPanes { foldCollapsed = false }
        } else {
            isMaximized = true
        }
    }
}

// MARK: - Desk mode

/// The flat half of a half-folded Duo: pane switcher, refresh timers and layouts, so the
/// upright half is all web content.
private struct DeskDeck: View {
    let session: SessionController
    let sidebarModel: SidebarModel
    let mode: PaneMode
    let width: CGFloat
    let searchProvider: SearchProvider
    @Binding var isEditingAddress: Bool
    let openLayouts: () -> Void
    let openSettings: () -> Void

    private var grid: GridModel { session.grid }

    var body: some View {
        @Bindable var grid = grid

        VStack(spacing: 10) {
            HStack(spacing: 8) {
                ForEach(Array(grid.panes.enumerated()), id: \.element.id) { index, pane in
                    paneCard(pane, index: index)
                }
                if grid.paneCount < PaneLimits.maxInnerPanes {
                    Button { session.addPane(mode: mode) } label: {
                        Image(systemName: "plus")
                            .font(.title3.weight(.semibold))
                            .frame(width: 56, height: 64)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 16))
                    .accessibilityLabel(Text("Add Pane"))
                }
            }

            HStack(spacing: 8) {
                if !isEditingAddress {
                    deckButton("Back", systemImage: "chevron.backward") { grid.selectedCell?.goBack() }
                    deckButton("Forward", systemImage: "chevron.forward") { grid.selectedCell?.goForward() }
                }
                AddressBarView(
                    text: $grid.addressText,
                    placeholder: String(localized: "Search or enter a URL"),
                    availableWidth: width,
                    reservedControlWidth: 4 * 44 + 4 * 8 + 16,
                    onSubmit: { grid.submitAddress(using: searchProvider) },
                    onEditingChanged: { editing in
                        withAnimation(.snappy) { isEditingAddress = editing }
                    }
                )
                .frame(maxWidth: .infinity)
                if !isEditingAddress {
                    deckButton("Reload", systemImage: "arrow.clockwise") { grid.selectedCell?.reloadCell() }
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    Button { session.savePaneLayout() } label: {
                        Label("Save Layout", systemImage: "plus")
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 14)
                            .frame(minHeight: 44)
                    }
                    .buttonStyle(.plain)
                    .glassEffect(.regular.interactive(), in: .capsule)

                    ForEach(sidebarModel.presets) { preset in
                        Button { session.applyPaneLayout(preset, mode: mode) } label: {
                            Text(preset.name.isEmpty ? String(localized: "Untitled Preset") : preset.name)
                                .font(.subheadline.weight(.semibold))
                                .lineLimit(1)
                                .padding(.horizontal, 14)
                                .frame(minHeight: 44)
                        }
                        .buttonStyle(.plain)
                        .glassEffect(.regular.interactive(), in: .capsule)
                    }

                    Button(action: openLayouts) {
                        Image(systemName: "ellipsis")
                            .frame(width: 44, height: 44)
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .glassEffect(.regular.interactive(), in: .circle)
                    .accessibilityLabel(Text("Layouts & Bookmarks"))

                    Button(action: openSettings) {
                        Image(systemName: "gearshape")
                            .frame(width: 44, height: 44)
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .glassEffect(.regular.interactive(), in: .circle)
                    .accessibilityLabel(Text("Settings"))
                }
            }
        }
        .padding(.horizontal, 6)
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private func deckButton(_ title: LocalizedStringKey, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .frame(width: 44, height: 44)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .circle)
        .accessibilityLabel(Text(title))
    }

    private func paneCard(_ pane: WaffleCell, index: Int) -> some View {
        let isSelected = grid.selectedCell == pane
        return Menu {
            AutoRefreshMenu(
                selection: pane.refreshInterval,
                onSelect: { grid.setRefreshInterval($0, for: pane) }
            )
            if grid.paneCount > 1 {
                Button(role: .destructive) { session.removePane(pane) } label: {
                    Label("Close Pane", systemImage: "xmark.rectangle")
                }
            }
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text("\(index + 1)")
                        .font(.caption.weight(.bold))
                        .frame(width: 20, height: 20)
                        .background(isSelected ? Color.waffleTertiary : Color.secondary.opacity(0.3), in: Circle())
                        .foregroundStyle(isSelected ? Color.white : Color.primary)
                    if pane.refreshInterval != .off {
                        Image(systemName: "timer").font(.caption)
                    }
                }
                Text(pane.address.isEmpty ? String(localized: "Empty Pane") : URLDisplayFormatter.compact(pane.address))
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
            }
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
            .contentShape(Rectangle())
        } primaryAction: {
            grid.select(pane)
        }
        .buttonStyle(.plain)
        .glassEffect(isSelected ? .regular.tint(Color.accentColor.opacity(0.25)).interactive() : .regular.interactive(), in: .rect(cornerRadius: 16))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
#endif
