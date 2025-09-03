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
    
    var body: some View {
        Grid(horizontalSpacing: 4, verticalSpacing: 4) {
            ForEach(0..<waffleState.waffleRows.count, id: \.self) { waffleRow in
                GridRow {
                    ForEach(waffleState.waffleRows[waffleRow]) { waffleColumn in
                        if fullscreenCell == waffleColumn {
                            Color.clear
                                .overlay {
                                    let isSelected = waffleState.selectedCell == waffleColumn
                                    if isSelected {
                                        Rectangle()
                                            .strokeBorder(.waffleSecondary, lineWidth: 4)
                                            .padding(-4)
                                            .ignoresSafeArea()
                                    }
                                }
                        } else {
                            WebView(waffleColumn.page)
                                .onAppear {
                                    if waffleColumn.address.isEmpty {
                                        waffleColumn.address = "https://apple.com"
                                    }

                                    waffleColumn.loadURL(urlString: waffleColumn.address)
                                }
                                .onChange(of: waffleColumn.page.url) {
                                    waffleColumn.address = waffleColumn.page.url?.absoluteString ?? ""
                                    if waffleState.selectedCell == waffleColumn {
                                        addressBarString = waffleColumn.page.url?.absoluteString ?? ""
                                    }
                                }
                                .overlay {
                                    let isPoppedOut = waffleState.isPoppedOut(waffleColumn)
                                    let isSelected = waffleState.selectedCell == waffleColumn
                                    
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
                                    }
                                    else if isSelected {
                                        Rectangle()
                                            .strokeBorder(Color.accentColor, lineWidth: 4)
                                            .padding(-4)
                                            .ignoresSafeArea()
                                    } else {
                                        Button {
                                            waffleState.select(waffleColumn)
                                            addressBarString = waffleColumn.page.url?.absoluteString ?? ""
                                        } label: {
                                            Color.clear
                                        }
                                    }
                                }
                        }
                    }
                }
            }
        }
        .background(Color(white: 0.9))
        .onAppear(perform: waffleState.makeInitialItem)
    }
}

#Preview {
    WaffleGridView(
        waffleState: .constant(WaffleState()),
        addressBarString: .constant(""),
        requestPopBack: {}
    )
}
