//
//  IdentifiedURL.swift
//  Waffle
//
//  Created by Nick Molargik on 9/3/25.
//

import Foundation

struct IdentifiedURL: Identifiable, Equatable {
    let id = UUID()
    let url: URL
}
