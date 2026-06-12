//
//  RearrangeWaffleView.swift
//  Waffle
//
//  Created by Nick Molargik on 9/3/25.
//

import SwiftUI
import WebKit

/// Sheet for reordering the waffle grid. The layout mirrors the real grid's
/// rows × columns geometry, and every tile shows the live page's title and
/// favicon so cells are recognizable at a glance. Two ways to move cells:
/// drag to reorder (shifting everything after the drop point), or tap two
/// cells to swap just those two.
struct RearrangeWaffleView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(WaffleCoordinator.self) private var coordinator

    @State private var cells: [RearrangeCell] = []
    @State private var originalCells: [RearrangeCell] = []
    @State private var swapSource: RearrangeCell.ID? = nil

    let rows: Int
    let cols: Int
    let onCancel: () -> Void
    let onSave: ([String]) -> Void

    private var hasChanges: Bool { cells != originalCells }

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
                        Label(String(localized: "No Cells"), systemImage: "square.grid.3x3.slash")
                    } description: {
                        Text("There are no cells to rearrange.")
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    GeometryReader { geometry in
                        gridView(in: geometry.size)
                    }
                    .padding(20)
                }
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Cancel")) {
                        onCancel()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .principal) {
                    Button(String(localized: "Reset"), systemImage: "arrow.uturn.backward") {
                        withAnimation(.spring(response: 0.3)) {
                            cells = originalCells
                            swapSource = nil
                        }
                    }
                    .buttonStyle(.glass)
                    .disabled(!hasChanges)
                    .accessibilityHint(Text("Restores the original order"))
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "Save")) {
                        onSave(cells.map(\.url))
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(!hasChanges)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear {
            loadCells()
        }
        .frame(minWidth: 540, minHeight: 480)
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
                    Text(verbatim: "\(rows) × \(cols)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.waffleSecondary.opacity(0.3), in: Capsule())
            }

            Group {
                if swapSource == nil {
                    Text("Drag a cell to reorder, or tap two cells to swap them")
                } else {
                    Label(String(localized: "Now tap another cell to swap"), systemImage: "arrow.left.arrow.right")
                        .foregroundStyle(Color.accentColor)
                }
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .contentTransition(.opacity)
            .animation(.easeInOut(duration: 0.15), value: swapSource == nil)
        }
    }

    // MARK: - Grid

    /// Uses iOS 27's reorderable ForEach: the container interprets drops and
    /// hands back a ReorderDifference instead of manual NSItemProvider plumbing.
    /// Tiles are sized so the sheet's grid keeps the real grid's geometry.
    private func gridView(in size: CGSize) -> some View {
        let spacing: CGFloat = 8
        let rowCount = max(1, rows)
        let tileHeight = max(60, (size.height - spacing * CGFloat(rowCount - 1)) / CGFloat(rowCount))
        let columns = Array(repeating: GridItem(.flexible(), spacing: spacing), count: max(1, cols))

        return LazyVGrid(columns: columns, spacing: spacing) {
            ForEach(Array(cells.enumerated()), id: \.element.id) { index, cell in
                RearrangeTileView(
                    cell: cell,
                    index: index,
                    isSwapSource: swapSource == cell.id,
                    onTap: { handleTap(cell.id) },
                    onClear: { clearCell(cell.id) }
                )
                .frame(height: tileHeight)
            }
            .reorderable()
        }
        .reorderContainer(for: RearrangeCell.self) { difference in
            withAnimation(.spring(response: 0.3)) {
                applyReorder(difference)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .accessibilityLabel(Text("Rearrangeable grid"))
    }

    // MARK: - Actions

    private func applyReorder(_ difference: ReorderDifference<RearrangeCell.ID, ReorderableSingleCollectionIdentifier>) {
        let ids = Set(difference.sources)
        let destination: RearrangeCell.ID? = switch difference.destination.position {
        case .before(let id): id
        case .end: nil
        }
        cells = GridLayout.movedItems(cells, withIDs: ids, before: destination)
        swapSource = nil
    }

    private func handleTap(_ id: RearrangeCell.ID) {
        guard let source = swapSource else {
            swapSource = id
            return
        }
        defer { swapSource = nil }
        guard source != id,
              let first = cells.firstIndex(where: { $0.id == source }),
              let second = cells.firstIndex(where: { $0.id == id }) else { return }
        withAnimation(.spring(response: 0.3)) {
            cells = GridLayout.swapped(cells, first, second)
        }
    }

    private func clearCell(_ id: RearrangeCell.ID) {
        guard let index = cells.firstIndex(where: { $0.id == id }) else { return }
        withAnimation(.spring(response: 0.3)) {
            cells[index].clear()
            if swapSource == id {
                swapSource = nil
            }
        }
    }

    private func loadCells() {
        cells = coordinator.waffleState.waffleRows.flatMap { row in
            row.map { RearrangeCell(id: UUID(), url: $0.address, title: $0.page.title) }
        }
        originalCells = cells
    }
}

// MARK: - Tile

/// A single tile in the rearrange grid: favicon, page title, and compact URL,
/// with the app's accent-glow treatment when chosen for a swap.
private struct RearrangeTileView: View {
    let cell: RearrangeCell
    let index: Int
    let isSwapSource: Bool
    let onTap: () -> Void
    let onClear: () -> Void

    private var faviconURL: URL? {
        guard let host = URL(string: cell.url)?.host() else { return nil }
        return URL(string: "https://\(host)/favicon.ico")
    }

    var body: some View {
        ZStack {
            if cell.isEmpty {
                LinearGradient(
                    colors: [Color.wafflePrimary.opacity(0.4), Color.waffleSecondary.opacity(0.3)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                VStack(spacing: 6) {
                    Image(systemName: "globe.badge.chevron.backward")
                        .font(.title3)
                        .foregroundStyle(.tertiary)
                    Text("Empty")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            } else {
                Color(uiColor: .secondarySystemGroupedBackground)

                VStack(spacing: 8) {
                    faviconView

                    VStack(spacing: 2) {
                        if !cell.title.isEmpty {
                            Text(verbatim: cell.title)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .lineLimit(1)
                        }
                        Text(verbatim: URLDisplayFormatter.compact(cell.url))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
                .padding(.horizontal, 10)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(alignment: .topLeading) {
            Text(verbatim: "\(index + 1)")
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(Color.waffleTertiary, in: Circle())
                .padding(6)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .stroke(isSwapSource ? Color.accentColor : Color.clear, lineWidth: 3)
                .shadow(color: isSwapSource ? Color.accentColor.opacity(0.5) : .clear, radius: 8)
                .padding(1)
        }
        .scaleEffect(isSwapSource ? 1.02 : 1.0)
        .animation(.spring(response: 0.3), value: isSwapSource)
        .contentShape(RoundedRectangle(cornerRadius: 14))
        .onTapGesture(perform: onTap)
        .contextMenu {
            if !cell.isEmpty {
                Button(role: .destructive) {
                    onClear()
                } label: {
                    Label(String(localized: "Clear Cell"), systemImage: "xmark.circle")
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            cell.isEmpty
                ? Text("Position \(index + 1), empty")
                : Text("Position \(index + 1), \(cell.title.isEmpty ? URLDisplayFormatter.compact(cell.url) : cell.title)")
        )
        .accessibilityHint(
            isSwapSource
                ? Text("Chosen for swapping. Tap another cell to swap.")
                : Text("Drag to reorder, or tap to choose for swapping")
        )
        .accessibilityAddTraits(isSwapSource ? .isSelected : [])
    }

    private var faviconView: some View {
        AsyncImage(url: faviconURL) { phase in
            if let image = phase.image {
                image
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            } else {
                Image(systemName: "globe")
                    .font(.title3)
                    .foregroundStyle(Color.waffleSecondary)
            }
        }
        .frame(width: 28, height: 28)
    }
}

#Preview {
    RearrangeWaffleView(rows: 2, cols: 2, onCancel: {}, onSave: { _ in })
        .environment(PreviewSupport.makeCoordinator())
}
