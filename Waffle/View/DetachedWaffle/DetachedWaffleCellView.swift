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
    @Environment(WaffleCoordinator.self) private var coordinator: WaffleCoordinator
    
    let waffleCell: WaffleCell

    @AppStorage("poppedCellAddress") private var poppedCellAddress: String = ""
    @AppStorage("searchProvider") private var searchProviderRawValue: String = SearchProvider.google.rawValue
    
    private var searchProvider: SearchProvider {
        get { SearchProvider(rawValue: searchProviderRawValue) ?? .google }
        set { searchProviderRawValue = newValue.rawValue }
    }

    @State private var viewModel = DetachedWaffleCellView.ViewModel()
    
    var body: some View {
        NavigationStack {
            Color(.clear)
                .frame(height: 0)

            Group {
                if waffleCell.address.isEmpty {
                    EmptyCellView()
                } else {
                    WebView(waffleCell.page)
                        .onAppear {
                            viewModel.addressBarString = waffleCell.address
                            waffleCell.loadURL(urlString: waffleCell.address)
                            poppedCellAddress = waffleCell.address
                        }
                        .onChange(of: waffleCell.page.url) {
                            waffleCell.address = waffleCell.page.url?.absoluteString ?? ""
                            poppedCellAddress = waffleCell.address
                            viewModel.addressBarString = waffleCell.address
                        }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .toolbar {
                    ToolbarItemGroup(placement: .topBarLeading) {
                        Button("Back", systemImage: "chevron.backward") {
                            waffleCell.goBack()
                        }
                        
                        Button("Forward", systemImage: "chevron.forward") {
                            waffleCell.goForward()
                        }
                    }
                    
                    ToolbarItem(placement: .principal) {
                        SelectAllTextField(
                            text: $viewModel.addressBarString,
                            placeholder: "Search or enter a URL",
                            onSubmit: {
                                let final = AddressNormalizer.normalize(viewModel.addressBarString, using: searchProvider)
                                waffleCell.loadURL(urlString: final)
                            }
                        )
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .frame(minWidth: 200, idealWidth: 400, maxWidth: 600)
                        .fixedSize(horizontal: false, vertical: true)
                        .clipShape(Capsule())
                        .glassEffect(.regular, in: .capsule)
                    }
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            waffleCell.reloadCell()
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                        .buttonStyle(.glass)
                    }
                    
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        @Bindable var coord = coordinator
                        Button {
                            popBack()
                        } label: {
                            HStack {
                                Text("Pop Back")
                                
                                Image(systemName: "rectangle.on.rectangle.slash")
                            }
                        }
                    }
                }
                .toolbarTitleDisplayMode(.inline)
        }
    }
    
    private func popBack() {
        // Update state first, then dismiss window after a brief delay
        // to avoid WebKit animation race conditions during window teardown.
        coordinator.waffleState.popBack(poppedCellAddress: poppedCellAddress)
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(50))
            dismissWindow()
        }
    }
}

#Preview {
    let previewCell = WaffleCell()
    previewCell.loadURL(urlString: "https://www.google.com")
    return DetachedWaffleCellView(waffleCell: previewCell)
        .environment(WaffleCoordinator(store: StoreManager()))
}
