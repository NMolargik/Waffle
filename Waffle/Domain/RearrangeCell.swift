//
//  RearrangeCell.swift
//  Waffle
//
//  Created by Nick Molargik on 9/3/25.
//

import Foundation

/// A lightweight model used by the rearrange UI to represent a single grid slot.
///
/// This struct is separate from the live WaffleCell to avoid coupling the
/// rearrangement UI to web view state. It only carries what is needed for
/// reordering: a stable identifier, the URL string, and the page title.
struct RearrangeCell: Identifiable, Equatable {
    /// Stable identifier for diffing and list operations.
    let id: UUID
    /// The URL string assigned to this position.
    var url: String
    /// The loaded page's title, used as the tile's display name.
    var title: String = ""

    /// Whether this slot has no page assigned.
    var isEmpty: Bool { url.isEmpty }

    /// Empties the slot, turning it back into a blank cell.
    mutating func clear() {
        url = ""
        title = ""
    }
}
