//
//  TestDoubles.swift
//  WaffleTests
//
//  Fakes for every service seam.
//

import Foundation
@testable import Waffle

/// In-memory fake for the UserDefaults seam.
final class FakeKeyValueStore: KeyValueStoring {
    private(set) var storage: [String: Any] = [:]

    func data(forKey defaultName: String) -> Data? {
        storage[defaultName] as? Data
    }

    func string(forKey defaultName: String) -> String? {
        storage[defaultName] as? String
    }

    func bool(forKey defaultName: String) -> Bool {
        storage[defaultName] as? Bool ?? false
    }

    func integer(forKey defaultName: String) -> Int {
        storage[defaultName] as? Int ?? 0
    }

    func set(_ value: Any?, forKey defaultName: String) {
        storage[defaultName] = value
    }

    func removeObject(forKey defaultName: String) {
        storage.removeValue(forKey: defaultName)
    }
}

/// Records review prompt requests.
final class FakeReviewRequester: ReviewRequesting {
    private(set) var requestCount = 0

    func requestReview() {
        requestCount += 1
    }
}
