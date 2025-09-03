//
//  BookmarksHeaderView.swift
//  Waffle
//
//  Created by Nick Molargik on 9/3/25.
//

import SwiftUI

struct BookmarksHeaderView: View {
    var onQuickSaveCurrent: () -> Void
    var onSaveAs: () -> Void
    
    var body: some View {
        HStack {
            Group {
                Image(systemName: "bookmark.fill")
                    .foregroundStyle(LinearGradient(colors: [.yellow.opacity(0.7), .yellow.opacity(0.9)], startPoint: .top, endPoint: .bottom))
                    .frame(width: 40)
                Text("Bookmarks")
            }
            .fontWeight(.semibold)
            .font(.title2)
            .bold()
            
            Spacer()
            
            Menu {
                Button("Quick Save Current Tab", systemImage: "square.and.arrow.down.fill") { onQuickSaveCurrent() }
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
                .foregroundStyle(.wafflePrimary.opacity(0.4))
                .cornerRadius(20)
        }
    }
}

#Preview {
    BookmarksHeaderView(onQuickSaveCurrent: {}, onSaveAs: {})
}
