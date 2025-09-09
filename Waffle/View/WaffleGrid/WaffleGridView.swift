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
                                WebView(waffleCell.page)
                                    .onAppear {
                                        if waffleCell.address.isEmpty {
                                            waffleCell.address = "https://www.molargiksoftware.com/#/wafflelanding"
                                        }
                                        waffleCell.loadURL(urlString: waffleCell.address)
                                    }
                                    .onChange(of: waffleCell.page.url) {
                                        waffleCell.address = waffleCell.page.url?.absoluteString ?? ""
                                        if waffleState.selectedCell == waffleCell {
                                            addressBarString = waffleCell.page.url?.absoluteString ?? ""
                                        }
                                    }
                                    .overlay {
                                        let isPoppedOut = waffleState.isPoppedOut(waffleCell)
                                        let isSelected = waffleState.selectedCell == waffleCell
                                        
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
                                                        Capsule().fill(Color.white)
                                                    )
                                                    .foregroundStyle(.black)
                                                }
                                            }
                                        } else if isSelected {
                                            Rectangle()
                                                .strokeBorder(Color.blue, lineWidth: 4)
                                                .padding(-4)
                                        } else {
                                            Color.clear
                                                .contentShape(Rectangle())
                                                .onTapGesture {
                                                    waffleState.select(waffleCell)
                                                    addressBarString = waffleCell.page.url?.absoluteString ?? ""
                                                }
                                                .contextMenu {
                                                    Button("Copy To Selected Cell") {
                                                        copyToSelectedCell(waffleCell.address)
                                                    }
                                                }
                                        }
                                    }
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
}

#Preview {
    WaffleGridView(
        waffleState: .constant(WaffleState()),
        addressBarString: .constant(""),
        requestPopBack: {},
        copyToSelectedCell: { _ in }
    )
}
