//
//  Snapshot.swift
//  Waffle
//
//  Created by Nick Molargik on 9/3/25.
//

import Foundation

extension WaffleState {
    struct Snapshot: Codable {
        let rows: Int
        let cols: Int
        let urls: [String]
        let selectedIndex: Int?
    }
}
