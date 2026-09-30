//
//  Seams.swift
//  WaffleCore
//
//  Protocol seams over system frameworks, so logic stays testable and framework-free.
//  Concrete conformances live in WaffleData/WaffleServices — or in the app target when
//  they need app-only types (Spotlight entities, intent donation).
//

import Foundation

// MARK: - Key/value storage

/// Abstraction over UserDefaults-style key/value storage. Declared with UserDefaults'
/// exact method signatures so `UserDefaults` conforms for free.
nonisolated public protocol KeyValueStoring: AnyObject {
    func data(forKey defaultName: String) -> Data?
    func string(forKey defaultName: String) -> String?
    func bool(forKey defaultName: String) -> Bool
    func integer(forKey defaultName: String) -> Int
    func set(_ value: Any?, forKey defaultName: String)
    func removeObject(forKey defaultName: String)
}

extension UserDefaults: KeyValueStoring {}

// MARK: - Review prompting

/// Abstraction over the App Store review prompt so launch-milestone logic is testable.
/// The concrete requester (WaffleServices) resolves the active scene itself.
@MainActor
public protocol ReviewRequesting {
    func requestReview()
}

// MARK: - Spotlight indexing

/// Abstraction over Spotlight's semantic index. The concrete indexer lives in the app
/// target (it maps models to `AppEntity` types, which can't live in the package).
@MainActor
public protocol LibraryIndexing {
    /// Replaces the index contents with entries for the given library.
    func reindex(presets: [Preset], bookmarks: [Bookmark])
}

// MARK: - Entitlements

/// Abstraction over the Syrup purchase state, so entitlement gating is testable without
/// StoreKit. `StoreManager` (WaffleServices) is the production conformance.
@MainActor
public protocol EntitlementProviding: AnyObject {
    var isPurchased: Bool { get }
}

// MARK: - Intent donation

/// Abstraction over Siri intent donation for preset opens (teaches Siri which presets
/// the user reaches for). The concrete donor lives in the app target with the intents.
@MainActor
public protocol PresetDonating {
    func donateOpenPreset(_ preset: Preset)
}

/// Attaches the app-entity identifier to the browsing user activity when the current page
/// matches a saved bookmark (the AppIntents entity types live in the app target).
@MainActor
public protocol BrowsingActivityAnnotating {
    func annotate(_ activity: NSUserActivity, matching bookmark: Bookmark)
}
