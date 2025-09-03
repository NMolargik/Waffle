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
            
            WebView(waffleCell.page)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .onAppear {
                    let addr = waffleCell.address.isEmpty ? "https://apple.com" : waffleCell.address
                    viewModel.addressBarString = addr
                    waffleCell.loadURL(urlString: addr)
                }
                .onChange(of: waffleCell.page.url) {
                    waffleCell.address = waffleCell.page.url?.absoluteString ?? ""
                    poppedCellAddress = waffleCell.address
                }
                .onDisappear {
                    popBack()
                }
                .toolbar {
                    ToolbarItemGroup(placement: .topBarLeading) {
                        Button("Back", systemImage: "chevron.backward") {
                            coordinator.waffleState.selectedCell?.goBack()
                        }
                        
                        Button("Forward", systemImage: "chevron.forward") {
                            coordinator.waffleState.selectedCell?.goForward()
                        }
                    }
                    
                    ToolbarItem(placement: .principal) {
                        HStack {
                            HStack {
                                TextField("Address", text: $viewModel.addressBarString)
                                    .padding(10)
                                    .glassEffect(.regular, in: .capsule)
                                    .textContentType(.URL)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                                    .onSubmit {
                                        let final = viewModel.normalizedInput(viewModel.addressBarString, using: searchProvider)
                                        coordinator.waffleState.selectedCell?.loadURL(urlString: final)
                                    }
                                    .frame(idealWidth: 300)

                                
                                Button {
                                    coordinator.waffleState.selectedCell?.reloadCell()
                                } label: {
                                    Label("Refresh", systemImage: "arrow.clockwise")
                                        .frame(maxHeight: .infinity)
                                }
                                .buttonStyle(.glass)
                                
                            }
                        }
                    }
                    
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        @Bindable var coord = coordinator
                        Button("Pop Back", systemImage: "rectangle.on.rectangle.slash") {
                            popBack()
                        }
                    }
                }
                .toolbarTitleDisplayMode(.inline)
        }
    }
    
    private func popBack() {
        // Only reattach if this window was showing the actually-detached square.
        if coordinator.waffleState.isPoppedOut(waffleCell) {
            coordinator.waffleState.popBack(poppedCellAddress: poppedCellAddress)
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
