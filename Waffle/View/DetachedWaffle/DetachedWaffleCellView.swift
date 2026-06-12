//
//  DetachedWaffleCellView.swift
//  Waffle
//
//  Created by Nick Molargik on 9/2/25.
//

import SwiftUI
import WebKit

struct DetachedWaffleCellView: View {
    @Environment(\.dismissWindow) private var dismissWindow
    @Environment(\.openWindow) private var openWindow
    @Environment(WaffleCoordinator.self) private var coordinator

    let waffleCell: WaffleCell

    @AppStorage("poppedCellAddress") private var poppedCellAddress: String = ""
    @AppStorage("searchProvider") private var searchProviderRawValue: String = SearchProvider.google.rawValue

    @State private var addressBarString: String = ""
    /// Window content width, measured so the address bar can fill it.
    @State private var windowWidth: CGFloat = 0

    private var searchProvider: SearchProvider {
        SearchProvider(rawValue: searchProviderRawValue) ?? .google
    }

    var body: some View {
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
                    Button(String(localized: "Back"), systemImage: "chevron.backward") {
                        waffleCell.goBack()
                    }
                    .accessibilityHint(Text("Goes back a page"))

                    Button(String(localized: "Forward"), systemImage: "chevron.forward") {
                        waffleCell.goForward()
                    }
                    .accessibilityHint(Text("Goes forward a page"))
                }
                .visibilityPriority(.low)

                ToolbarItem(placement: .principal) {
                    HStack(spacing: 8) {
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

                        AddressBarView(
                            text: $addressBarString,
                            placeholder: String(localized: "Search or enter a URL"),
                            availableWidth: windowWidth,
                            reservedControlWidth: 320,
                            onSubmit: {
                                let final = AddressNormalizer.normalize(addressBarString, using: searchProvider)
                                waffleCell.loadURL(urlString: final)
                            }
                        )
                    }
                }
                .visibilityPriority(.high)

                ToolbarItem(placement: .topBarTrailing) {
                    Button(String(localized: "Pop Back"), systemImage: "rectangle.on.rectangle.slash") {
                        popBack()
                    }
                    .accessibilityHint(Text("Returns this cell to the grid"))
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
        coordinator.waffleState.popBack(poppedCellAddress: poppedCellAddress)
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(50))
            // Opening unconditionally would spawn a second main window when
            // one is already open — only restore it when none exists.
            if coordinator.mainWindowCount == 0 {
                openWindow(id: "main")
            }
            dismissWindow()
        }
    }
}

#Preview {
    let previewCell = WaffleCell()
    previewCell.loadURL(urlString: "https://www.google.com")
    return DetachedWaffleCellView(waffleCell: previewCell)
        .environment(PreviewSupport.makeCoordinator())
}
