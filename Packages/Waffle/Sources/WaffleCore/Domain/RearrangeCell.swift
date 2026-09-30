//
//  RearrangeCell.swift
//  WaffleCore
//
//  A lightweight model used by the rearrange UI to represent a single grid slot,
//  decoupled from live web view state.
//

import Foundation

nonisolated public struct RearrangeCell: Identifiable, Equatable, Sendable {
    /// Stable identifier for diffing and list operations.
    public let id: UUID
    /// The URL string assigned to this position.
    public var url: String
    /// The loaded page's title, used as the tile's display name.
    public var title: String

    public init(id: UUID, url: String, title: String = "") {
        self.id = id
        self.url = url
        self.title = title
    }

    /// Whether this slot has no page assigned.
    public var isEmpty: Bool { url.isEmpty }

    /// Empties the slot, turning it back into a blank cell.
    public mutating func clear() {
        url = ""
        title = ""
    }
}
