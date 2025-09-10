//
//  RearrangeWaffleView.swift
//  Waffle
//
//  Created by Nick Molargik on 9/3/25.
//

import SwiftUI
import UniformTypeIdentifiers

struct RearrangeWaffleView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(WaffleCoordinator.self) private var coordinator

    let rows: Int
    let cols: Int

    @State private var viewModel = RearrangeWaffleView.ViewModel()

    let onCancel: () -> Void
    let onSave: ([String]) -> Void

    init(urls: [String] = [], rows: Int, cols: Int, onCancel: @escaping () -> Void, onSave: @escaping ([String]) -> Void) {
        self.rows = rows
        self.cols = cols
        self.onCancel = onCancel
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("Rearrange Waffle")
                    .font(.title2)
                    .bold()

                let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: max(1, cols))

                if viewModel.tiles.isEmpty {
                    ContentUnavailableView("No Cells", systemImage: "square.grid.3x3", description: Text("There are no cells to rearrange yet."))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    Text("Tap and hold, then drag the cell when it lifts from the waffle to rearrange.")
                        .font(.subheadline)
                        .bold()
                    
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(viewModel.tiles) { tile in
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.waffleSecondary)
                                    .overlay(
                                        Text(tile.url)
                                            .font(.caption)
                                            .foregroundStyle(.primary)
                                            .multilineTextAlignment(.center)
                                            .padding(10)
                                            .lineLimit(1)
                                            .truncationMode(.tail)
                                            .minimumScaleFactor(0.6)
                                            .background {
                                                Rectangle()
                                                    .foregroundStyle(.ultraThinMaterial)
                                                    .cornerRadius(20)
                                            }
                                            .padding()
                                    )
                                    .shadow(radius: 2)
                                    .frame(height: 80)
                                    .onDrag {
                                        viewModel.draggingID = tile.id
                                        return NSItemProvider(object: tile.id.uuidString as NSString)
                                    }
                                    .onDrop(of: [.text], delegate: WaffleDropDelegate(
                                        targetID: tile.id,
                                        items: $viewModel.tiles,
                                        currentID: $viewModel.draggingID
                                    ))
                            }
                        }
                        .padding(.top, 4)
                    }
                }
            }
            .padding()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(viewModel.produceSavePayload())
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            resyncFromCoordinator()
        }

        .onChange(of: coordinator.waffleState.rowCount) { _, _ in
            resyncFromCoordinator()
        }
        .onChange(of: coordinator.waffleState.colCount) { _, _ in
            resyncFromCoordinator()
        }
        .onChange(of: coordinator.waffleState.selectedCell?.id) { _, _ in
            resyncFromCoordinator()
        }
        .frame(minWidth: 500, minHeight: 400)
    }

    private func resyncFromCoordinator() {
        let urls = coordinator.waffleState.flattenedAddresses()
        withAnimation(.snappy) {
            viewModel.resyncFrom(urls: urls)
        }
    }
}

#Preview {
    RearrangeWaffleView(urls: ["a", "b", "c", "d"], rows: 2, cols: 2, onCancel: {}, onSave: { _ in })
        .environment(WaffleCoordinator(store: StoreManager()))
}
