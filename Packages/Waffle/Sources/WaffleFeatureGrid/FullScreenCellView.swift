//
//  FullScreenCellView.swift
//  WaffleFeatureGrid
//
//  Fullscreen presentation of one cell. The web view is revealed one tick after the
//  overlay appears so the WebKit layer isn't re-parented mid-animation.
//

#if os(iOS)
import SwiftUI
import WebKit

public struct FullScreenCellView: View {
    let model: GridModel
    var cell: WaffleCell

    @State private var showWebView = false

    public init(model: GridModel, cell: WaffleCell) {
        self.model = model
        self.cell = cell
    }

    public var body: some View {
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
                                model.noteAddressChange(for: cell)
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
    FullScreenCellView(model: GridModel(), cell: WaffleCell())
}
#endif
