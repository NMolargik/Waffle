//
//  WaffleGridView.swift
//  Waffle
//
//  Created by Nick Molargik on 9/2/25.
//

import SwiftUI
import WebKit

struct WaffleGridView: View {
    @Environment(\.openWindow) private var openWindow
    @Binding var waffleState: WaffleState
    @Binding var addressBarString: String

    var requestPopBack: () -> Void
    var fullscreenCell: WaffleCell? = nil
    var copyToSelectedCell: (String) -> Void

    /// Corner radius for cells, concentric with iPad screen corners (~18pt screen radius - 14pt inset)
    private let cellCornerRadius: CGFloat = 18

    var body: some View {
        GeometryReader { geometry in
            let rowCount = max(1, waffleState.rowCount)
            let colCount = max(1, waffleState.colCount)
            let cellHeight = max(1, (geometry.size.height - CGFloat(rowCount - 1) * 4) / CGFloat(rowCount))
            let cellWidth = max(1, (geometry.size.width - CGFloat(colCount - 1) * 4) / CGFloat(colCount))

            Grid(horizontalSpacing: 4, verticalSpacing: 4) {
                let rowIndices = Array(waffleState.waffleRows.indices)

                ForEach(rowIndices, id: \.self) { rowIndex in
                    // Validate the index at render-time to avoid out-of-bounds during rapid mutations.
                    if rowIndex < waffleState.waffleRows.count {
                        let rowCells = waffleState.waffleRows[rowIndex]
                        let rowID = rowCells.first?.id ?? UUID()

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
                                    cellContent(for: waffleCell)
                                        .frame(width: cellWidth, height: cellHeight)
                                        // Column transitions: trailing edge
                                        .transition(.asymmetric(
                                            insertion: .move(edge: .trailing).combined(with: .opacity),
                                            removal: .move(edge: .trailing).combined(with: .opacity)
                                        ))
                                }
                            }
                        }
                        .id(rowID)
                        .transition(.asymmetric(
                            insertion: .move(edge: .bottom).combined(with: .opacity),
                            removal: .move(edge: .bottom).combined(with: .opacity)
                        ))
                    } else {
                        // Index became invalid during this render pass; render nothing safely.
                        EmptyView()
                    }
                }
            }
        }
        .animation(.snappy, value: waffleState.rowCount)
        .animation(.snappy, value: waffleState.colCount)
        .animation(.snappy, value: waffleState.waffleRows.map { $0.map(\.id) })
    }

    @ViewBuilder
    private func cellContent(for waffleCell: WaffleCell) -> some View {
        let isPoppedOut = waffleState.isPoppedOut(waffleCell)
        let isSelected = waffleState.selectedCell == waffleCell
        let isEmpty = waffleCell.address.isEmpty

        WaffleCellContainer(
            waffleCell: waffleCell,
            isPoppedOut: isPoppedOut,
            isSelected: isSelected,
            isEmpty: isEmpty,
            cornerRadius: cellCornerRadius,
            addressBarString: $addressBarString,
            waffleState: $waffleState,
            requestPopBack: requestPopBack,
            copyToSelectedCell: copyToSelectedCell
        )
    }
}

/// Separate container view to enable @State for hover tracking
private struct WaffleCellContainer: View {
    let waffleCell: WaffleCell
    let isPoppedOut: Bool
    let isSelected: Bool
    let isEmpty: Bool
    let cornerRadius: CGFloat
    @Binding var addressBarString: String
    @Binding var waffleState: WaffleState
    let requestPopBack: () -> Void
    let copyToSelectedCell: (String) -> Void

    @State private var isHovered = false

    var body: some View {
        Group {
            if isEmpty {
                EmptyCellView()
            } else {
                WebView(waffleCell.page)
                    .onAppear {
                        waffleCell.loadURL(urlString: waffleCell.address)
                    }
                    .onChange(of: waffleCell.page.url) {
                        waffleCell.address = waffleCell.page.url?.absoluteString ?? ""
                        if waffleState.selectedCell == waffleCell {
                            addressBarString = waffleCell.page.url?.absoluteString ?? ""
                        }
                    }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .overlay(alignment: .top) {
            // Loading progress bar
            if waffleCell.isLoading && !isEmpty {
                GeometryReader { geo in
                    Rectangle()
                        .fill(Color.accentColor)
                        .frame(width: geo.size.width * waffleCell.loadingProgress, height: 3)
                        .animation(.easeInOut(duration: 0.2), value: waffleCell.loadingProgress)
                }
                .frame(height: 3)
            }
        }
        .overlay {
            if isPoppedOut {
                ZStack {
                    // Warm gradient background matching EmptyCellView
                    LinearGradient(
                        colors: [Color.wafflePrimary, Color.waffleSecondary],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )

                    // Content card
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

                            Button {
                                requestPopBack()
                            } label: {
                                Label("Pop Back", systemImage: "arrow.down.backward")
                                    .fontWeight(.semibold)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(Color.waffleTertiary)
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

                            Button {
                                requestPopBack()
                            } label: {
                                Label("Pop Back", systemImage: "arrow.down.backward")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(Color.waffleTertiary)
                        }
                        .padding(16)
                        .background(.thickMaterial, in: RoundedRectangle(cornerRadius: 16))
                        .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
                        .padding(20)

                        // Minimal version
                        Button {
                            requestPopBack()
                        } label: {
                            Label("Pop Back", systemImage: "arrow.down.backward")
                                .font(.caption)
                                .fontWeight(.semibold)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Color.waffleTertiary)
                        .padding(8)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
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
                        addressBarString = waffleCell.address
                    }
                    .contextMenu {
                        if !isEmpty {
                            Button("Copy To Selected Cell") {
                                copyToSelectedCell(waffleCell.address)
                            }
                        }
                    }
            }
        }
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

#Preview {
    WaffleGridView(
        waffleState: .constant(WaffleState()),
        addressBarString: .constant(""),
        requestPopBack: {},
        copyToSelectedCell: { _ in }
    )
}
