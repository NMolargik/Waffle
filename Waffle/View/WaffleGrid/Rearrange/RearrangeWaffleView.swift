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

    @State private var cells: [RearrangeCell] = []
    @State private var draggedCell: RearrangeCell?
    @State private var originalCells: [RearrangeCell] = []

    let rows: Int
    let cols: Int
    let onCancel: () -> Void
    let onSave: ([String]) -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                headerView
                    .padding(.horizontal, 24)
                    .padding(.top, 20)
                    .padding(.bottom, 16)

                Divider()

                if cells.isEmpty {
                    ContentUnavailableView {
                        Label("No Cells", systemImage: "square.grid.3x3.slash")
                    } description: {
                        Text("There are no cells to rearrange.")
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    gridView
                        .padding(20)
                }
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(cells.map(\.url))
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear {
            loadCells()
        }
        .frame(minWidth: 500, minHeight: 450)
    }

    // MARK: - Header

    private var headerView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Rearrange Grid")
                    .font(.title2)
                    .fontWeight(.bold)

                Spacer()

                HStack(spacing: 4) {
                    Image(systemName: "square.grid.3x3")
                        .font(.caption)
                    Text("\(rows) × \(cols)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.waffleSecondary.opacity(0.3), in: Capsule())
            }

            Text("Drag cells to swap their positions")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Grid

    private var gridView: some View {
        GeometryReader { geometry in
            let spacing: CGFloat = 8
            let availableWidth = geometry.size.width
            let availableHeight = geometry.size.height
            let cellWidth = (availableWidth - (spacing * CGFloat(cols - 1))) / CGFloat(cols)
            let cellHeight = (availableHeight - (spacing * CGFloat(rows - 1))) / CGFloat(rows)

            VStack(spacing: spacing) {
                ForEach(0..<rows, id: \.self) { row in
                    HStack(spacing: spacing) {
                        ForEach(0..<cols, id: \.self) { col in
                            let index = row * cols + col
                            if index < cells.count {
                                cellView(for: cells[index], at: index)
                                    .frame(width: cellWidth, height: cellHeight)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Cell View

    private func cellView(for cell: RearrangeCell, at index: Int) -> some View {
        let isBeingDragged = draggedCell?.id == cell.id
        let isDragTarget = draggedCell != nil && draggedCell?.id != cell.id

        return VStack(spacing: 6) {
            // Position badge
            Text("\(index + 1)")
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(Color.waffleTertiary, in: Circle())

            // URL display
            if cell.url.isEmpty {
                Image(systemName: "globe.badge.chevron.backward")
                    .font(.title2)
                    .foregroundStyle(.tertiary)
                Text("Empty")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            } else {
                Image(systemName: "globe")
                    .font(.title2)
                    .foregroundStyle(Color.waffleSecondary)
                Text(displayURL(for: cell.url))
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .truncationMode(.middle)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(cell.url.isEmpty
                    ? Color(uiColor: .tertiarySystemFill)
                    : Color(uiColor: .secondarySystemGroupedBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isDragTarget ? Color.waffleTertiary : Color.clear, lineWidth: 2)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isDragTarget ? Color.waffleTertiary.opacity(0.1) : Color.clear)
                )
        )
        .scaleEffect(isBeingDragged ? 1.05 : 1.0)
        .opacity(isBeingDragged ? 0.7 : 1.0)
        .shadow(color: .black.opacity(isBeingDragged ? 0.2 : 0.05), radius: isBeingDragged ? 10 : 4)
        .animation(.spring(response: 0.3), value: isBeingDragged)
        .animation(.spring(response: 0.3), value: isDragTarget)
        .onDrag {
            draggedCell = cell
            return NSItemProvider(object: cell.id.uuidString as NSString)
        }
        .onDrop(of: [.text], isTargeted: nil) { _ in
            guard let dragged = draggedCell, dragged.id != cell.id else {
                draggedCell = nil
                return false
            }

            // Swap the cells
            if let fromIndex = cells.firstIndex(where: { $0.id == dragged.id }),
               let toIndex = cells.firstIndex(where: { $0.id == cell.id }) {
                withAnimation(.spring(response: 0.3)) {
                    cells.swapAt(fromIndex, toIndex)
                }
            }

            draggedCell = nil
            return true
        }
    }

    // MARK: - Helpers

    private func loadCells() {
        let urls = coordinator.waffleState.flattenedAddresses()
        cells = urls.enumerated().map { index, url in
            RearrangeCell(id: UUID(), url: url)
        }
        originalCells = cells
    }

    private func displayURL(for urlString: String) -> String {
        var url = urlString
        if url.hasPrefix("https://") { url = String(url.dropFirst(8)) }
        else if url.hasPrefix("http://") { url = String(url.dropFirst(7)) }
        if url.hasPrefix("www.") { url = String(url.dropFirst(4)) }
        if let slashIndex = url.firstIndex(of: "/") {
            let domain = String(url[..<slashIndex])
            let path = String(url[slashIndex...])
            if path.count > 10 { return domain }
        }
        return url
    }
}

#Preview {
    RearrangeWaffleView(rows: 2, cols: 2, onCancel: {}, onSave: { _ in })
        .environment(WaffleCoordinator(store: StoreManager()))
}
