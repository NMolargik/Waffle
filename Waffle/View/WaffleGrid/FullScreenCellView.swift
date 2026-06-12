//
//  FullScreenCellView.swift
//  Waffle
//
//  Created by Nick Molargik on 9/2/25.
//

import SwiftUI
import WebKit

struct FullScreenCellView: View {
    @Environment(WaffleCoordinator.self) private var coordinator

    var cell: WaffleCell

    // Reveal the web view one tick after the overlay appears so the WebKit
    // layer isn't re-parented mid-animation.
    @State private var showWebView = false

    var body: some View {
        ZStack {
            Rectangle()
                .strokeBorder(Color.accentColor, lineWidth: 4)
                .padding(-4)
                .ignoresSafeArea()

            Rectangle()
                .foregroundStyle(.ultraThinMaterial)
                .ignoresSafeArea()
                .onAppear {
                    showWebView = true
                }
                .onDisappear {
                    showWebView = false
                }

            if showWebView {
                Group {
                    if cell.address.isEmpty {
                        EmptyCellView()
                    } else {
                        WebView(cell.page)
                            .webViewBackForwardNavigationGestures(.enabled)
                            .webViewMagnificationGestures(.enabled)
                            .webViewLinkPreviews(.enabled)
                            .onAppear {
                                cell.loadURL(urlString: cell.address)
                            }
                            .onChange(of: cell.page.url) {
                                cell.address = cell.page.url?.absoluteString ?? ""
                                coordinator.waffleState.noteAddressChange(for: cell)
                            }
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 25))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding([.top, .horizontal])
            }
        }
        .transition(.opacity)
        .shadow(radius: 5)
        .accessibilityLabel(Text("Fullscreen cell"))
    }
}

#Preview {
    FullScreenCellView(cell: WaffleCell())
        .environment(PreviewSupport.makeCoordinator())
}
