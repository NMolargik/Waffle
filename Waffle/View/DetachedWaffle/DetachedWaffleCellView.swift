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
                    let defaultAddr = "https://www.molargiksoftware.com/#/wafflelanding"
                    let addr = waffleCell.address.isEmpty ? defaultAddr : waffleCell.address
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
                            waffleCell.goBack()
                        }
                        
                        Button("Forward", systemImage: "chevron.forward") {
                            waffleCell.goForward()
                        }
                    }
                    
                    ToolbarItem(placement: .principal) {
                        HStack {
                            HStack {
                                SelectAllTextField(
                                    text: $viewModel.addressBarString,
                                    placeholder: "Search or enter a URL",
                                    onSubmit: {
                                        let final = viewModel.normalizedInput(viewModel.addressBarString, using: searchProvider)
                                        waffleCell.loadURL(urlString: final)
                                    }
                                )
                                .padding(10)
                                .glassEffect(.regular, in: .capsule)
                                .frame(idealWidth: 500)

                                Button {
                                    waffleCell.reloadCell()
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
        coordinator.waffleState.popBack(poppedCellAddress: poppedCellAddress)
        dismissWindow()
    }
}

#Preview {
    let previewCell = WaffleCell()
    previewCell.loadURL(urlString: "https://www.google.com")
    return DetachedWaffleCellView(waffleCell: previewCell)
        .environment(WaffleCoordinator(store: StoreManager()))
}
