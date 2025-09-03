//
//  RearrangeWaffleView-ViewModel.swift
//  Waffle
//
//  Created by Nick Molargik on 9/3/25.
//

import Foundation

extension RearrangeWaffleView {
    @Observable
    class ViewModel {
        var tiles: [RearrangeCell] = []
        var draggingID: UUID?

        func resyncFrom(urls: [String]) {
            tiles = urls.map { RearrangeCell(id: UUID(), url: $0) }
        }

        func produceSavePayload() -> [String] {
            tiles.map { $0.url }
        }
    }
}
