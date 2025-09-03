//
//  WaffleDropDelegate.swift
//  Waffle
//
//  Created by Nick Molargik on 9/3/25.
//

import SwiftUI

struct WaffleDropDelegate: DropDelegate {
    let targetID: UUID
    @Binding var items: [RearrangeCell]
    @Binding var currentID: UUID?
    
    func dropEntered(info: DropInfo) {
        guard let currentID, currentID != targetID,
              let from = items.firstIndex(where: { $0.id == currentID }),
              let to = items.firstIndex(where: { $0.id == targetID }) else { return }
        withAnimation(.snappy) {
            items.move(fromOffsets: IndexSet(integer: from), toOffset: to > from ? to + 1 : to)
        }
    }
    
    func performDrop(info: DropInfo) -> Bool {
        currentID = nil
        return true
    }
    
    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }
}
