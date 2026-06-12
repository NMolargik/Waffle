//
//  ReviewRequesting.swift
//  Waffle
//
//  Seam over StoreKit's review prompt so launch-milestone logic is testable.
//

import StoreKit
import UIKit

/// Abstraction over the App Store review prompt.
@MainActor
protocol ReviewRequesting {
    func requestReview()
}

/// Production conformance that finds a foreground scene and asks StoreKit.
struct AppStoreReviewRequester: ReviewRequesting {
    nonisolated init() {}

    func requestReview() {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        guard let scene = scenes.first(where: { $0.activationState == .foregroundActive }) ?? scenes.first else {
            return
        }
        AppStore.requestReview(in: scene)
    }
}
