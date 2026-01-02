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
    
    var body: some View {
        Grid(horizontalSpacing: 4, verticalSpacing: 4) {
            // Take a snapshot of valid indices to iterate over.
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
                                    .transition(.asymmetric(
                                        insertion: .move(edge: .trailing).combined(with: .opacity),
                                        removal: .move(edge: .trailing).combined(with: .opacity)
                                    ))
                            } else {
                                cellContent(for: waffleCell)
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
                    Rectangle()
                        .foregroundStyle(Color.accentColor)
                    VStack {
                        Text("This cell has been")
                            .font(.subheadline)
                        Text("Popped Out")
                            .font(.title)
                        Button(action: {
                            requestPopBack()
                        }, label: {
                            HStack {
                                Image(systemName: "arrow.down.backward")
                                Text("Pop Back")
                            }
                        })
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            Capsule().fill(Color.wafflePrimary)
                        )
                        .foregroundStyle(Color.waffleTertiary)
                    }
                }
            } else if isSelected {
                // Soft glow selection instead of harsh border
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.accentColor, lineWidth: 3)
                    .shadow(color: Color.accentColor.opacity(0.5), radius: 8)
                    .padding(1)
            } else {
                // Hover highlight for non-selected cells
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.accentColor.opacity(isHovered ? 0.6 : 0), lineWidth: 2)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
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
