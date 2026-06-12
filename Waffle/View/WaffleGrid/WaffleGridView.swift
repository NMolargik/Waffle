//
//  WaffleGridView.swift
//  Waffle
//
//  Created by Nick Molargik on 9/2/25.
//

import SwiftUI
import WebKit

struct WaffleGridView: View {
    let waffleState: WaffleState
    var requestPopBack: () -> Void
    var fullscreenCell: WaffleCell? = nil

    /// Corner radius for cells, concentric with iPad screen corners (~18pt screen radius - 14pt inset)
    private let cellCornerRadius: CGFloat = 18

    var body: some View {
        GeometryReader { geometry in
            let rowCount = max(1, waffleState.rowCount)
            let colCount = max(1, waffleState.colCount)
            let cellHeight = max(1, (geometry.size.height - CGFloat(rowCount - 1) * 4) / CGFloat(rowCount))
            let cellWidth = max(1, (geometry.size.width - CGFloat(colCount - 1) * 4) / CGFloat(colCount))

            Grid(horizontalSpacing: 4, verticalSpacing: 4) {
                ForEach(Array(waffleState.waffleRows.enumerated()), id: \.element.first?.id) { rowIndex, rowCells in
                    GridRow {
                        ForEach(rowCells) { waffleCell in
                            if fullscreenCell == waffleCell {
                                Color.clear
                                    .frame(width: cellWidth, height: cellHeight)
                                    .transition(.asymmetric(
                                        insertion: .move(edge: .trailing).combined(with: .opacity),
                                        removal: .move(edge: .trailing).combined(with: .opacity)
                                    ))
                            } else {
                                WaffleCellContainer(
                                    waffleCell: waffleCell,
                                    waffleState: waffleState,
                                    cornerRadius: cellCornerRadius,
                                    requestPopBack: requestPopBack
                                )
                                .frame(width: cellWidth, height: cellHeight)
                                .transition(.asymmetric(
                                    insertion: .move(edge: .trailing).combined(with: .opacity),
                                    removal: .move(edge: .trailing).combined(with: .opacity)
                                ))
                            }
                        }
                    }
                    .accessibilityElement(children: .contain)
                    .accessibilityLabel(Text("Row \(rowIndex + 1)"))
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .move(edge: .bottom).combined(with: .opacity)
                    ))
                }
            }
        }
        .animation(.snappy, value: waffleState.rowCount)
        .animation(.snappy, value: waffleState.colCount)
        .animation(.snappy, value: waffleState.waffleRows.map { $0.map(\.id) })
    }
}

/// Separate container view to enable @State for hover tracking
private struct WaffleCellContainer: View {
    let waffleCell: WaffleCell
    let waffleState: WaffleState
    let cornerRadius: CGFloat
    let requestPopBack: () -> Void

    @State private var isHovered = false

    private var isPoppedOut: Bool { waffleState.isPoppedOut(waffleCell) }
    private var isSelected: Bool { waffleState.selectedCell == waffleCell }
    private var isEmpty: Bool { waffleCell.address.isEmpty }

    var body: some View {
        Group {
            if isEmpty {
                EmptyCellView()
            } else {
                WebView(waffleCell.page)
                    .webViewBackForwardNavigationGestures(.enabled)
                    .webViewMagnificationGestures(.enabled)
                    .webViewLinkPreviews(.enabled)
                    .onAppear {
                        waffleCell.loadURL(urlString: waffleCell.address)
                    }
                    .onChange(of: waffleCell.page.url) {
                        waffleCell.address = waffleCell.page.url?.absoluteString ?? ""
                        waffleState.noteAddressChange(for: waffleCell)
                    }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .overlay {
            if isPoppedOut {
                PoppedOutPlaceholder(cornerRadius: cornerRadius, requestPopBack: requestPopBack)
            } else if isSelected {
                // Soft glow selection instead of harsh border
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(Color.accentColor, lineWidth: 3)
                    .shadow(color: Color.accentColor.opacity(0.5), radius: 8)
                    .padding(1)
            } else {
                // Hover highlight for non-selected cells
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(Color.accentColor.opacity(isHovered ? 0.6 : 0), lineWidth: 2)
                    .background(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .fill(Color.accentColor.opacity(isHovered ? 0.08 : 0))
                    )
                    .animation(.easeInOut(duration: 0.15), value: isHovered)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        waffleState.select(waffleCell)
                    }
                    .contextMenu {
                        if !isEmpty {
                            Button(String(localized: "Copy To Selected Cell")) {
                                waffleState.loadInSelectedCell(waffleCell.address)
                            }
                        }
                    }
            }
        }
        .overlay {
            // Loading indicator: the cell's own rounded border fills in as
            // the page loads. It hugs the waffle shape (no straight strip
            // jutting past the corners) and uses the brand tertiary color.
            // Applied after the selection overlay so it draws on top of the
            // accent selection stroke instead of hiding beneath it.
            if waffleCell.isLoading && !isEmpty {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .trim(from: 0, to: waffleCell.loadingProgress)
                    .stroke(
                        Color.waffleTertiary,
                        style: StrokeStyle(lineWidth: 3, lineCap: .round)
                    )
                    .padding(1.5)
                    .animation(.easeInOut(duration: 0.2), value: waffleCell.loadingProgress)
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }
        }
        .onHover { hovering in
            isHovered = hovering
        }
        // Accept URL drops (e.g. a bookmark dragged from the sidebar).
        .dropDestination(for: URL.self) { urls, _ in
            guard let url = urls.first else { return false }
            waffleCell.loadURL(urlString: url.absoluteString)
            waffleState.select(waffleCell)
            return true
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(accessibilityCellLabel)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityHint(isSelected ? Text("") : Text("Double tap to select this cell"))
    }

    private var accessibilityCellLabel: Text {
        if isEmpty {
            return Text("Empty cell")
        }
        if !waffleCell.page.title.isEmpty {
            return Text(waffleCell.page.title)
        }
        return Text(URLDisplayFormatter.compact(waffleCell.address))
    }
}

/// Overlay shown in the grid slot of a cell that is open in another window.
private struct PoppedOutPlaceholder: View {
    let cornerRadius: CGFloat
    let requestPopBack: () -> Void

    var body: some View {
        ZStack {
            // Warm gradient background matching EmptyCellView
            LinearGradient(
                colors: [Color.wafflePrimary, Color.waffleSecondary],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            ViewThatFits(in: .vertical) {
                // Full version
                VStack(spacing: 16) {
                    Text("Popped Out")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(.primary)

                    Text("This cell is open in another window")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding()
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))

                    popBackButton
                        .fontWeight(.semibold)
                }
                .padding(24)
                .background(.thickMaterial, in: RoundedRectangle(cornerRadius: 20))
                .shadow(color: .black.opacity(0.1), radius: 10, y: 5)
                .padding(40)

                // Compact version
                VStack(spacing: 12) {
                    Text("Popped Out")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundStyle(.primary)

                    popBackButton
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                .padding(16)
                .background(.thickMaterial, in: RoundedRectangle(cornerRadius: 16))
                .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
                .padding(20)

                // Minimal version
                popBackButton
                    .font(.caption)
                    .fontWeight(.semibold)
                    .padding(8)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }

    private var popBackButton: some View {
        Button {
            requestPopBack()
        } label: {
            Label(String(localized: "Pop Back"), systemImage: "arrow.down.backward")
        }
        .buttonStyle(.borderedProminent)
        .tint(Color.waffleTertiary)
        .accessibilityHint(Text("Returns the cell to the grid"))
    }
}

#Preview {
    WaffleGridView(
        waffleState: WaffleState(),
        requestPopBack: {}
    )
}
