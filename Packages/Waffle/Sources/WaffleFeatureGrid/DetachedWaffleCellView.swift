//
//  DetachedWaffleCellView.swift
//  WaffleFeatureGrid
//
//  A popped-out cell in its own window. The composition root injects the pop-back
//  action and the one-primary-window check (a WebPage crashes WebKit when hosted by
//  two WebViews, so the main window is only reopened when none exists).
//

#if os(iOS)
import SwiftUI
import WebKit
import WaffleCore

public struct DetachedWaffleCellView: View {
    @Environment(\.dismissWindow) private var dismissWindow
    @Environment(\.openWindow) private var openWindow

    let waffleCell: WaffleCell
    /// Returns the popped cell to the grid (composition wires GridModel.popBack).
    let onPopBack: (String) -> Void
    /// True when no main window exists, so pop-back should reopen it.
    let shouldReopenMainWindow: () -> Bool

    @AppStorage("poppedCellAddress") private var poppedCellAddress: String = ""
    @AppStorage("searchProvider") private var searchProviderRawValue: String = SearchProvider.google.rawValue

    @State private var addressBarString: String = ""
    /// Window content width, measured so the address bar can fill it.
    @State private var windowWidth: CGFloat = 0
    /// While the address bar has focus it takes the whole toolbar; the other
    /// controls hide until editing ends.
    @State private var isEditingAddress = false

    public init(
        waffleCell: WaffleCell,
        onPopBack: @escaping (String) -> Void,
        shouldReopenMainWindow: @escaping () -> Bool
    ) {
        self.waffleCell = waffleCell
        self.onPopBack = onPopBack
        self.shouldReopenMainWindow = shouldReopenMainWindow
    }

    private var searchProvider: SearchProvider {
        SearchProvider(rawValue: searchProviderRawValue) ?? .google
    }

    public var body: some View {
        NavigationStack {
            Color(.clear)
                .frame(height: 0)

            Group {
                if waffleCell.address.isEmpty {
                    EmptyCellView()
                } else {
                    WebView(waffleCell.page)
                        .webViewBackForwardNavigationGestures(.enabled)
                        .webViewMagnificationGestures(.enabled)
                        .webViewLinkPreviews(.enabled)
                        .onAppear {
                            addressBarString = waffleCell.address
                            waffleCell.loadURL(urlString: waffleCell.address)
                            poppedCellAddress = waffleCell.address
                        }
                        .onChange(of: waffleCell.page.url) {
                            waffleCell.address = waffleCell.page.url?.absoluteString ?? ""
                            poppedCellAddress = waffleCell.address
                            addressBarString = waffleCell.address
                        }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onGeometryChange(for: CGFloat.self) { proxy in
                proxy.size.width
            } action: { newWidth in
                windowWidth = newWidth
            }
            .toolbar {
                // Back/forward fold into the More menu first when the window
                // narrows; the address bar and Pop Back stay visible.
                ToolbarItemGroup(placement: .topBarLeading) {
                    if !isEditingAddress {
                        Button(String(localized: "Back"), systemImage: "chevron.backward") {
                            waffleCell.goBack()
                        }
                        .accessibilityHint(Text("Goes back a page"))

                        Button(String(localized: "Forward"), systemImage: "chevron.forward") {
                            waffleCell.goForward()
                        }
                        .accessibilityHint(Text("Goes forward a page"))
                    }
                }
                .visibilityPriority(.low)

                ToolbarItem(placement: .principal) {
                    HStack(spacing: 8) {
                        if !isEditingAddress {
                            Button {
                                waffleCell.reloadCell()
                            } label: {
                                Image(systemName: "arrow.clockwise")
                                    .frame(
                                        width: AppConfiguration.barControlHeight,
                                        height: AppConfiguration.barControlHeight
                                    )
                                    .contentShape(Circle())
                            }
                            .buttonStyle(.plain)
                            .glassEffect(.regular.interactive(), in: .circle)
                            .accessibilityLabel(Text("Reload"))
                            .transition(.scale.combined(with: .opacity))
                        }

                        AddressBarView(
                            text: $addressBarString,
                            placeholder: String(localized: "Search or enter a URL"),
                            availableWidth: windowWidth,
                            reservedControlWidth: 320,
                            onSubmit: {
                                let final = AddressNormalizer.normalize(addressBarString, using: searchProvider)
                                waffleCell.loadURL(urlString: final)
                            },
                            onEditingChanged: { editing in
                                withAnimation(.snappy) { isEditingAddress = editing }
                            }
                        )
                    }
                }
                .visibilityPriority(.high)

                ToolbarItem(placement: .topBarTrailing) {
                    if !isEditingAddress {
                        Button(String(localized: "Pop Back"), systemImage: "rectangle.on.rectangle.slash") {
                            popBack()
                        }
                        .accessibilityHint(Text("Returns this cell to the grid"))
                    }
                }
                .visibilityPriority(.high)
            }
            .toolbarTitleDisplayMode(.inline)
        }
        .navigationTitle(waffleCell.page.title)
    }

    private func popBack() {
        // Update state first, then dismiss window after a brief delay
        // to avoid WebKit animation race conditions during window teardown.
        onPopBack(poppedCellAddress)
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(50))
            // Opening unconditionally would spawn a second main window when
            // one is already open — only restore it when none exists.
            if shouldReopenMainWindow() {
                openWindow(id: "main")
            }
            dismissWindow()
        }
    }
}
#endif
