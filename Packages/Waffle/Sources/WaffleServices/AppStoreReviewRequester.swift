//
//  AppStoreReviewRequester.swift
//  WaffleServices
//
//  Production `ReviewRequesting` conformance: finds a foreground scene and asks StoreKit.
//

import StoreKit
import WaffleCore
#if canImport(UIKit)
import UIKit
#endif

public struct AppStoreReviewRequester: ReviewRequesting {
    public nonisolated init() {}

    public func requestReview() {
        #if canImport(UIKit) && !os(watchOS)
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        guard let scene = scenes.first(where: { $0.activationState == .foregroundActive }) ?? scenes.first else {
            return
        }
        AppStore.requestReview(in: scene)
        #endif
    }
}
