//
//  FullScreenCellView.swift
//  Waffle
//
//  Created by Nick Molargik on 9/2/25.
//

import SwiftUI
import WebKit

struct FullScreenCellView: View {
    @Environment(WaffleCoordinator.self) private var coordinator: WaffleCoordinator
    @Binding var viewModel: MainView.ViewModel
    var cell: WaffleCell
    
    var body: some View {
        ZStack {
            Rectangle()
                .strokeBorder(Color.accent, lineWidth: 4)
                .padding(-4)
                .ignoresSafeArea()
            
            
            Rectangle()
                .foregroundStyle(.ultraThinMaterial)
                .ignoresSafeArea()
                .onAppear {
                    // Cancel any prior task
                    viewModel.fullscreenTask?.cancel()
                    
                    viewModel.showFullScreenWebView = false
                    viewModel.fullscreenTask = Task { @MainActor in
                        viewModel.showFullScreenWebView = true
                    }
                }
                .onDisappear {
                    viewModel.fullscreenTask?.cancel()
                    viewModel.fullscreenTask = nil
                    viewModel.showFullScreenWebView = false
                }
            
            if viewModel.showFullScreenWebView {
                WebView(cell.page)
                    .onAppear {
                        if cell.address.isEmpty {
                            cell.address = "https://google.com"
                        }
                        cell.loadURL(urlString: cell.address)
                    }
                    .onChange(of: cell.page.url) {
                        cell.address = cell.page.url?.absoluteString ?? ""
                        if coordinator.waffleState.selectedCell == cell {
                            viewModel.addressBarString = cell.page.url?.absoluteString ?? ""
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding()
                    .cornerRadius(20)
            }
        }
        .transition(.opacity)
    }
}

#Preview {
    FullScreenCellView(
        viewModel: .constant(MainView.ViewModel()),
        cell: WaffleCell()
    )
    .environment(WaffleCoordinator(store: StoreManager()))
}
