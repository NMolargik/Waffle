//
//  EmptyCellView.swift
//  WaffleFeatureGrid
//
//  A placeholder view shown in cells that don't have a URL loaded yet.
//

#if os(iOS)
import SwiftUI
import WaffleDesignSystem

public struct EmptyCellView: View {
    public init() {}

    public var body: some View {
        ZStack {
            // Warm gradient background matching app theme
            LinearGradient(
                colors: [Color.wafflePrimary, Color.waffleSecondary],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Content card - use ViewThatFits to hide instructions when space is limited
            ViewThatFits(in: .vertical) {
                fullContent
                compactContent
                minimalContent
            }
        }
    }

    private var fullContent: some View {
        VStack(spacing: 16) {
            Text("Empty Cell")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(.primary)

            VStack(spacing: 8) {
                instructionRow("Tap a **cell** to activate it")
                instructionRow("Use the address bar to search or navigate")
                instructionRow("Open the menu for Presets & Bookmarks")
            }
            .padding()
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
        .padding(24)
        .background(.thickMaterial, in: RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.1), radius: 10, y: 5)
        .padding(40)
    }

    private var compactContent: some View {
        Text("Empty Cell")
            .font(.title2)
            .fontWeight(.bold)
            .foregroundStyle(.primary)
            .padding(16)
            .background(.thickMaterial, in: RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
            .padding(20)
    }

    private var minimalContent: some View {
        Text("Empty Cell")
            .font(.headline)
            .fontWeight(.bold)
            .foregroundStyle(.primary)
            .padding(8)
            .background(.thickMaterial, in: RoundedRectangle(cornerRadius: 12))
            .padding(8)
    }

    private func instructionRow(_ text: LocalizedStringKey) -> some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
    }
}

#Preview {
    EmptyCellView()
        .frame(width: 400, height: 300)
}
#endif
