//
//  EmptyCellView.swift
//  Waffle
//
//  Created by Nick Molargik on 9/3/25.
//

import SwiftUI

/// A placeholder view shown in cells that don't have a URL loaded yet.
struct EmptyCellView: View {
    var body: some View {
        ZStack {
            // Warm gradient background matching app theme
            LinearGradient(
                colors: [Color.wafflePrimary, Color.waffleSecondary],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Content card
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
