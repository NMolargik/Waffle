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
    /// The half-folded laptop pose is showing the desk deck (mirrors the geometry-derived value).
    @State private var inDeskMode = false
    /// Half-folded laptop pose on the inner display (desk mode itself needs Syrup).
    @State private var inLaptopPose = false
    /// The user hid the "Desk Mode" offer in the ••• menu for good.
    @AppStorage("deskModeOfferDismissed") private var deskOfferDismissed = false
    @State private var isEditingAddress = false
    /// The pane whose address is being edited; a submit navigates only this pane.
    @State private var editingPaneID: UUID?
    /// Bumped to end address editing without submitting (Cancel, or another pane was selected).
    @State private var dismissEditingToken = 0
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
        guard let index = PaneFocus.focusedIndex(
            count: grid.paneCount, mode: mode, isDeskMode: inDeskMode,
            isMaximized: isMaximized, selected: grid.selectedPaneIndex
        ) else { return nil }
        return grid.panes[index].id
    }

    /// Panes tucked away behind the focused one; their auto-refresh timers pause.
    private var hiddenPaneIDs: Set<UUID> {
        guard let focused = focusedPaneID else { return [] }
        return Set(grid.panes.map(\.id)).subtracting([focused])
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
            // The reader sits inside the safe area. The layout works in screen coordinates (the
            // fold is reported in the reader's space and converted by its origin), so rebuild
            // the screen size and shift results back into the reader's space when placing views.
            let inset = proxy.safeAreaInsets
            let screenSize = CGSize(
                width: proxy.size.width + inset.leading + inset.trailing,
                height: proxy.size.height + inset.top + inset.bottom
            )
            let origin = CGPoint(x: inset.leading, y: inset.top)
            let reading = FoldSensing.reading(in: proxy, screenSize: screenSize)
            let laptopPose = mode == .inner
                && reading?.isActive == true
                && reading?.gutter.primaryIsHorizontal == false
                && (effectiveHinge == .partiallyOpen || effectiveHinge == .unknown)
            let isDesk = laptopPose && session.canUseDeskMode
            let layout = PhoneScreenLayout.compute(
                size: screenSize,
                safe: (inset.top, inset.leading, inset.bottom, inset.trailing),
                fold: reading?.gutter,
                mode: mode,
                deskMode: isDesk,
                barOnFarSide: selectedPaneIsOnFarSide(primaryIsHorizontal: reading?.gutter.primaryIsHorizontal ?? (screenSize.width >= screenSize.height)),
                barHeight: barHeight
            )

            ZStack(alignment: .topLeading) {
                PaneWorkspaceView(
                    model: grid,
                    primaryIsHorizontal: layout.primaryIsHorizontal,
                    fold: layout.fold,
                    focusedPaneID: focusedPaneID,
                    onAddPane: { session.addPane(mode: mode, isFoldable: Self.isFoldableDevice) }
                )
                .frame(width: layout.workspace.width, height: layout.workspace.height)
                .offset(x: layout.workspace.minX - origin.x, y: layout.workspace.minY - origin.y)

                Color.clear.frame(width: 0, height: 0)
                    .onChange(of: laptopPose, initial: true) { _, now in inLaptopPose = now }
                    .onChange(of: isDesk, initial: true) { _, now in
                        inDeskMode = now
                        isMaximized = PaneFocus.reconciledMaximized(isMaximized, count: grid.paneCount, isDeskMode: now)
                    }

                if let bar = layout.bar {
                    controlBar(width: bar.width)
                        .frame(width: bar.width, height: bar.height)
                        .offset(x: bar.minX - origin.x, y: bar.minY - origin.y)
                }

                if let deck = layout.deck {
                    DeskDeck(
                        session: session,
                        sidebarModel: sidebarModel,
                        mode: mode,
                        width: deck.width,
                        searchProvider: searchProvider,
                        isEditingAddress: $isEditingAddress,
                        editingPaneID: $editingPaneID,
                        dismissEditingToken: $dismissEditingToken,
                        openLayouts: { showLayoutsSheet = true },
                        openSettings: { showSettingsSheet = true }
                    )
                    .frame(width: deck.width, height: deck.height)
                    .offset(x: deck.minX - origin.x, y: deck.minY - origin.y)
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
            sidebarModel.load()
            #if DEBUG
            DebugPaneSeeding.applyIfRequested(to: grid)
            let defaults = UserDefaults.standard
            if defaults.bool(forKey: "WaffleDebugMaximize") { isMaximized = true }
            switch defaults.string(forKey: "WaffleDebugSheet") {
            case "layouts": showLayoutsSheet = true
            case "settings": showSettingsSheet = true
            default: break
            }
            if defaults.string(forKey: "WaffleDebugAction") == "saveLayoutTwice" {
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(1500))
                    session.savePaneLayout()
                    try? await Task.sleep(for: .milliseconds(500))
                    session.savePaneLayout()
                }
            }
            if defaults.string(forKey: "WaffleDebugAction") == "addPane" {
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(1500))
                    session.addPane(mode: mode, isFoldable: Self.isFoldableDevice)
                }
            }
            #endif
        }
        .onChange(of: grid.selectedCell) { _, _ in
            // Selecting another pane ends editing: the field shows that pane's address again.
            if isEditingAddress { dismissEditingToken += 1 }
        }
        .onChange(of: grid.paneTouchCount) { _, _ in
            if isEditingAddress { dismissEditingToken += 1 }
        }
        .onChange(of: hiddenPaneIDs, initial: true) { _, hidden in
            grid.setHiddenCells(hidden)
        }
        .onChange(of: grid.paneCount) { _, count in
            isMaximized = PaneFocus.reconciledMaximized(isMaximized, count: count, isDeskMode: inDeskMode)
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
                phonePitch: SyrupPitch(
                    trigger: session.syrupTrigger,
                    device: mode == .inner ? .iPhoneDuoInner : (Self.isFoldableDevice ? .iPhoneDuoOuter : .iPhone)
                ),
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
        .toast(message: session.errorHandler.toastMessage, bottomInset: barHeight + PhoneScreenLayout.margin * 2 + 8) {
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

    /// The bar's circle controls stop scaling here so a glyph always stays inside its 44-point
    /// circle; the address field and labels scale up to the same cap.
    static let controlTypeLimit = DynamicTypeSize.xxxLarge

    /// Whether the focused pane is the only one visible while others are open behind it.
    private var showsSwitcher: Bool { focusedPaneID != nil && grid.paneCount > 2 }

    /// Duo, closed, three or four panes open: a line on the bar says unfolding shows them all.
    private var showsUnfoldHint: Bool {
        mode == .compact && grid.paneCount > PaneLimits.maxCompactPanes && Self.isFoldableDevice
    }

    private var barHeight: CGFloat {
        PhoneScreenLayout.barHeight + (showsUnfoldHint ? Self.hintHeight : 0)
    }
    static let hintHeight: CGFloat = 20

    static var isFoldableDevice: Bool {
        #if DEBUG
        if UserDefaults.standard.bool(forKey: "WaffleDebugFoldable") { return true }
        #endif
        var info = utsname()
        uname(&info)
        let machine = withUnsafeBytes(of: &info.machine) { raw in
            String(decoding: raw.prefix(while: { $0 != 0 }), as: UTF8.self)
        }
        let identifier = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] ?? machine
        return FoldableDevice.isFoldable(modelIdentifier: identifier)
    }

    private func controlBar(width: CGFloat) -> some View {
        @Bindable var grid = grid
        let showsMaximize = grid.paneCount > 1 && !(mode == .compact && grid.paneCount > PaneLimits.maxCompactPanes)
        let buttonCount = (showsMaximize ? 4 : 3)
        let reserved = CGFloat(buttonCount) * 44 + CGFloat(buttonCount) * 8 + 16 + (showsSwitcher ? Self.switcherWidth + 8 : 0)

        return VStack(spacing: 0) {
            if showsUnfoldHint && !isEditingAddress {
                Text("Unfold your iPhone Duo to see all \(grid.paneCount) panes")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .frame(height: Self.hintHeight)
                    .dynamicTypeSize(...Self.controlTypeLimit)
            }
            HStack(spacing: 8) {
                if !isEditingAddress {
                    circleButton("Back", systemImage: "chevron.backward") { grid.selectedCell?.goBack() }
                        .opacity(grid.selectedCell?.canGoBack == true ? 1 : 0.45)
                }

                AddressBarView(
                    text: $grid.addressText,
                    placeholder: String(localized: "Search or enter a URL"),
                    availableWidth: isEditingAddress ? width - Self.cancelButtonWidth : width,
                    reservedControlWidth: reserved,
                    onSubmit: { grid.submitAddress(using: searchProvider, toPaneID: editingPaneID) },
                    onEditingChanged: { editing in
                        editingPaneID = editing ? grid.selectedCell?.id : nil
                        withAnimation(.snappy) { isEditingAddress = editing }
                    },
                    dismissEditingToken: dismissEditingToken,
                    phoneStyle: true
                )

                if isEditingAddress {
                    cancelEditingButton
                } else {
                    if showsSwitcher { paneSwitcher }
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
            .frame(height: AppConfiguration.barControlHeight + 12)
        }
        .padding(.horizontal, 6)
    }

    /// Room the Cancel button takes beside the expanded address field.
    static let cancelButtonWidth: CGFloat = 84
    static let switcherWidth: CGFloat = 64

    private var cancelEditingButton: some View {
        Button { dismissEditingToken += 1 } label: {
            Text("Cancel")
                .font(.body)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .padding(.horizontal, 12)
                .frame(minWidth: 44, minHeight: AppConfiguration.barControlHeight)
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .capsule)
        .dynamicTypeSize(...Self.controlTypeLimit)
        .accessibilityHint(Text("Stops editing the address"))
    }

    /// "1 of 3": which pane is showing out of how many are open. Tap for the next pane;
    /// touch and hold to pick one.
    private var paneSwitcher: some View {
        let index = (grid.selectedPaneIndex ?? 0) + 1
        return Menu {
            paneList
        } label: {
            Text("\(index) of \(grid.paneCount)")
                .font(.footnote.weight(.semibold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(width: Self.switcherWidth, height: AppConfiguration.barControlHeight)
                .contentShape(Capsule())
        } primaryAction: {
            cycleSelectedPane()
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .capsule)
        .dynamicTypeSize(...Self.controlTypeLimit)
        .accessibilityLabel(Text("Pane \(index) of \(grid.paneCount)"))
        .accessibilityHint(Text("Shows the next pane. Touch and hold to choose a pane"))
    }

    @ViewBuilder
    private var paneList: some View {
        ForEach(Array(grid.panes.enumerated()), id: \.element.id) { index, pane in
            Button {
                grid.select(pane)
            } label: {
                Label(paneTitle(pane, index: index), systemImage: grid.selectedCell == pane ? "checkmark" : "rectangle")
            }
        }
    }

    private func cycleSelectedPane() {
        let panes = grid.panes
        guard panes.count > 1 else { return }
        let next = ((grid.selectedPaneIndex ?? -1) + 1) % panes.count
        grid.select(panes[next])
    }

    private func glyph(_ systemImage: String) -> some View {
        Image(systemName: systemImage)
            .dynamicTypeSize(...Self.controlTypeLimit)
            .frame(width: AppConfiguration.barControlHeight, height: AppConfiguration.barControlHeight)
            .contentShape(Circle())
    }

    private func circleButton(_ title: LocalizedStringKey, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            glyph(systemImage)
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
            glyph(grid.selectedCell?.refreshInterval == .off || grid.selectedCell == nil
                  ? "arrow.clockwise" : "arrow.trianglehead.2.clockwise.rotate.90")
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
            AutoRefreshMenu(
                selection: cell.refreshInterval,
                onSelect: { grid.setRefreshInterval($0, for: cell) }
            )
        }
    }

    /// The ••• menu, grouped and in reading order (`.menuOrder(.fixed)`: the first group is at
    /// the top and Settings, last, sits nearest the thumb and is never pushed off screen):
    /// this pane's arrangement, the page's own actions, layouts, then Settings.
    private var menuButton: some View {
        let addDecision = PaneLimits.addPane(currentCount: grid.paneCount, mode: mode, isSyrupEnabled: session.isSyrupEnabled)
        let atLimit = addDecision == .atDeviceLimit
        let selected = grid.selectedCell
        return Menu {
            // Panes
            Button { session.addPane(mode: mode, isFoldable: Self.isFoldableDevice) } label: {
                Label {
                    if atLimit {
                        Text("Add Pane") + Text(verbatim: " · ")
                            + Text(mode == .compact && Self.isFoldableDevice ? LocalizedStringKey("Unfold for More") : LocalizedStringKey("Limit Reached"))
                    } else {
                        Text("Add Pane")
                    }
                } icon: {
                    Image(systemName: "plus.rectangle.on.rectangle")
                }
            }
            .disabled(atLimit)

            if grid.paneCount > 1 {
                Button { toggleMaximize() } label: {
                    Label(
                        focusedPaneID == nil ? "Maximize Pane" : "Show All Panes",
                        systemImage: focusedPaneID == nil ? "arrow.up.left.and.arrow.down.right" : "arrow.down.right.and.arrow.up.left"
                    )
                }
            }
            if grid.paneCount == 2 {
                Button { grid.swapPanes(0, 1) } label: {
                    Label("Swap Panes", systemImage: "arrow.left.arrow.right")
                }
            }
            if grid.paneCount > 1, let selected {
                Button(role: .destructive) { session.removePane(selected) } label: {
                    Label("Close “\(paneName(selected))” Pane", systemImage: "xmark.rectangle")
                }
                if grid.paneCount > 2 {
                    Menu {
                        paneList
                    } label: {
                        Label("Go to Pane", systemImage: "rectangle.on.rectangle")
                    }
                }
            }

            Divider()

            // This pane's page, in one submenu so the menu stays short enough to show
            // Settings without scrolling.
            Menu {
                Button { grid.selectedCell?.goForward() } label: {
                    Label("Forward", systemImage: "chevron.forward")
                }
                .disabled(selected?.canGoForward != true)
                Button { grid.selectedCell?.reloadCell() } label: {
                    Label("Reload", systemImage: "arrow.clockwise")
                }
                .disabled(selected == nil)
                if let selected {
                    ContentBlockingMenu(
                        mode: selected.contentBlockingMode,
                        isActive: grid.contentBlocking.isActive(for: selected),
                        globalEnabled: grid.contentBlocking.isGloballyEnabled,
                        siteHasException: grid.contentBlocking.hasException(for: selected.address),
                        canExceptSite: ContentBlockingPolicy.normalizedHost(from: selected.address) != nil,
                        onSelect: { grid.setContentBlockingMode($0, for: selected) },
                        onToggleSite: { grid.toggleBlockingException(for: selected) }
                    )
                }
                autoRefreshItem
            } label: {
                Label("This Page", systemImage: "safari")
            }

            Divider()

            // Layouts
            Button { session.savePaneLayout() } label: {
                Label("Save Layout", systemImage: "square.and.arrow.down")
            }
            Button { showLayoutsSheet = true } label: {
                Label("Layouts & Bookmarks", systemImage: "rectangle.split.2x1")
            }

            Divider()

            if inLaptopPose, !session.canUseDeskMode, !deskOfferDismissed {
                Button { session.requestSyrup(for: .deskMode) } label: {
                    Label("Desk Mode", systemImage: "drop.fill")
                }
                Button { deskOfferDismissed = true } label: {
                    Label("Hide Desk Mode Offer", systemImage: "eye.slash")
                }
            }
            Button { showSettingsSheet = true } label: {
                Label("Settings", systemImage: "gearshape")
            }
        } label: {
            glyph("ellipsis")
        }
        .menuOrder(.fixed)
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .circle)
        .accessibilityLabel(Text("Panes and layouts"))
        .accessibilityHint(Text("Add or close panes, save layouts, and open settings"))
    }

    /// The pane's site, or "Pane N", for menu titles that name which pane an action affects.
    private func paneName(_ pane: WaffleCell) -> String {
        if !pane.address.isEmpty {
            let host = URLDisplayFormatter.phoneDisplay(pane.address)
            if let slash = host.firstIndex(of: "/") { return String(host[..<slash]) }
            return host
        }
        let index = (grid.panes.firstIndex(of: pane) ?? 0) + 1
        return String(localized: "Pane \(index)")
    }

    private func paneTitle(_ pane: WaffleCell, index: Int) -> String {
        if !pane.page.title.isEmpty { return pane.page.title }
        if !pane.address.isEmpty { return URLDisplayFormatter.phoneDisplay(pane.address) }
        return String(localized: "Pane \(index + 1)")
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
                        session.requestSyrup(for: .secondLayout)
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
        .presentationDetents([.large])
    }

    // MARK: - Actions

    private func toggleMaximize() {
        if focusedPaneID != nil {
            isMaximized = false
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
    @Binding var editingPaneID: UUID?
    @Binding var dismissEditingToken: Int
    let openLayouts: () -> Void
    let openSettings: () -> Void

    private var grid: GridModel { session.grid }

    var body: some View {
        @Bindable var grid = grid

        // Scrolls: in landscape (or at large text sizes) the deck's content is taller than
        // the flat half, and nothing may be cut off or sit tight against the bottom edge.
        ScrollView(.vertical) {
        VStack(alignment: .leading, spacing: 20) {
            // Panes: tall tiles with the page title and the refresh timer on the tile.
            sectionTitle("Panes")
            HStack(spacing: 10) {
                ForEach(Array(grid.panes.enumerated()), id: \.element.id) { index, pane in
                    paneTile(pane, index: index)
                }
                if grid.paneCount < PaneLimits.maxInnerPanes {
                    Button { session.addPane(mode: mode, isFoldable: PhoneMainView.isFoldableDevice) } label: {
                        Image(systemName: "plus")
                            .font(.title2.weight(.semibold))
                            .frame(width: 64)
                            .frame(maxHeight: .infinity)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 18))
                    .accessibilityLabel(Text("Add Pane"))
                }
            }
            .frame(minHeight: 168)
            .fixedSize(horizontal: false, vertical: true)

            // Address row.
            HStack(spacing: 8) {
                if !isEditingAddress {
                    deckButton("Back", systemImage: "chevron.backward") { grid.selectedCell?.goBack() }
                    deckButton("Forward", systemImage: "chevron.forward") { grid.selectedCell?.goForward() }
                }
                AddressBarView(
                    text: $grid.addressText,
                    placeholder: String(localized: "Search or enter a URL"),
                    availableWidth: isEditingAddress ? width - PhoneMainView.cancelButtonWidth : width,
                    reservedControlWidth: 4 * 44 + 4 * 8 + 16,
                    onSubmit: { grid.submitAddress(using: searchProvider, toPaneID: editingPaneID) },
                    onEditingChanged: { editing in
                        editingPaneID = editing ? grid.selectedCell?.id : nil
                        withAnimation(.snappy) { isEditingAddress = editing }
                    },
                    dismissEditingToken: dismissEditingToken,
                    phoneStyle: true
                )
                .frame(maxWidth: .infinity)
                if isEditingAddress {
                    Button { dismissEditingToken += 1 } label: {
                        Text("Cancel")
                            .padding(.horizontal, 12)
                            .frame(minWidth: 44, minHeight: 44)
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .glassEffect(.regular.interactive(), in: .capsule)
                }
                if !isEditingAddress {
                    deckButton("Reload", systemImage: "arrow.clockwise") { grid.selectedCell?.reloadCell() }
                    deckButton("Settings", systemImage: "gearshape", action: openSettings)
                }
            }

            // Layouts: one tap restores a saved arrangement.
            sectionTitle("Layouts")
            HStack(spacing: 8) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        Button { session.savePaneLayout() } label: {
                            Label("Save Layout", systemImage: "plus")
                                .font(.subheadline.weight(.semibold))
                                .padding(.horizontal, 14)
                                .frame(minHeight: 48)
                        }
                        .buttonStyle(.plain)
                        .glassEffect(.regular.interactive(), in: .capsule)

                        ForEach(sidebarModel.presets) { preset in
                            Button { session.applyPaneLayout(preset, mode: mode) } label: {
                                Text(preset.name.isEmpty ? String(localized: "Untitled Preset") : preset.name)
                                    .font(.subheadline.weight(.semibold))
                                    .lineLimit(1)
                                    .padding(.horizontal, 16)
                                    .frame(minHeight: 48)
                            }
                            .buttonStyle(.plain)
                            .glassEffect(.regular.interactive(), in: .capsule)
                        }
                    }
                }
                deckButton("Layouts & Bookmarks", systemImage: "ellipsis", action: openLayouts)
            }
        }
        .padding(.horizontal, 6)
        .padding(.bottom, 24)
        }
        .scrollBounceBehavior(.basedOnSize)
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private func sectionTitle(_ title: LocalizedStringKey) -> some View {
        Text(title)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .padding(.leading, 6)
    }

    private func deckButton(_ title: LocalizedStringKey, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .dynamicTypeSize(...PhoneMainView.controlTypeLimit)
                .frame(width: 44, height: 44)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .circle)
        .accessibilityLabel(Text(title))
    }

    /// A pane's tile: tap anywhere above the timer row to select it; the timer row is its own
    /// 44-point control (also holds Close Pane).
    private func paneTile(_ pane: WaffleCell, index: Int) -> some View {
        let isSelected = grid.selectedCell == pane
        return VStack(alignment: .leading, spacing: 0) {
            Button { grid.select(pane) } label: {
                VStack(alignment: .leading, spacing: 6) {
                    Text("\(index + 1)")
                        .font(.caption.weight(.bold))
                        .frame(width: 24, height: 24)
                        .background(isSelected ? Color.waffleTertiary : Color.secondary.opacity(0.3), in: Circle())
                        .foregroundStyle(isSelected ? Color.white : Color.primary)
                    Text(tileTitle(pane))
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    // A page that never loaded has no title, so the host is already the title.
                    if !pane.address.isEmpty, URLDisplayFormatter.phoneDisplay(pane.address) != tileTitle(pane) {
                        Text(URLDisplayFormatter.phoneDisplay(pane.address))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 12)
                .padding(.top, 12)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Menu {
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
                HStack(spacing: 6) {
                    Image(systemName: pane.refreshInterval == .off ? "timer" : "timer.circle.fill")
                    Text(pane.refreshInterval.title)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 12)
                .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("Auto-Refresh"))
        }
        // Unselected tiles get a faint fill under the glass: on a dark background glass alone
        // reads as a pale slab.
        .background(isSelected ? Color.clear : Color.primary.opacity(0.10), in: .rect(cornerRadius: 18))
        .glassEffect(isSelected ? .regular.tint(Color.accentColor.opacity(0.25)).interactive() : .regular.interactive(), in: .rect(cornerRadius: 18))
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func tileTitle(_ pane: WaffleCell) -> String {
        if !pane.page.title.isEmpty { return pane.page.title }
        if !pane.address.isEmpty { return URLDisplayFormatter.phoneDisplay(pane.address) }
        return String(localized: "Empty Pane")
    }
}
#endif
