//
//  PresetsHeaderView.swift
//  Waffle
//
//  Created by Nick Molargik on 9/3/25.
//

import SwiftUI

struct PresetsHeaderView: View {
    var onQuickSave: () -> Void
    var onSaveAs: () -> Void
    
    var body: some View {
        HStack {
            Group {
                Image(systemName: "square.grid.3x3.fill")
                    .foregroundStyle(
                        Color.waffleTertiary
                    )
                    .frame(width: 40)
                Text("Presets")
            }
            .font(.title2)
            .fontWeight(.semibold)
            .bold()
            
            Spacer()
            
            Menu {
                Button("Quick Save", systemImage: "square.and.arrow.down.fill") { onQuickSave() }
                Button("Save As…", systemImage: "square.and.pencil") { onSaveAs() }
            } label: {
                HStack {
                    Image(systemName: "plus")
                    Text("New")
                }
                .bold()
                .padding(10)
                .foregroundStyle(Color.primary)
                .glassEffect(.regular.interactive())
            }
            .menuStyle(.borderlessButton)
            .buttonStyle(.glass)
        }
        .padding(10)
        .background {
            Rectangle()
                .foregroundStyle(.waffleSecondary)
                .cornerRadius(15)
        }
        .padding(.horizontal, 10)
    }
}

#Preview {
    PresetsHeaderView(onQuickSave: {}, onSaveAs: {})
}
