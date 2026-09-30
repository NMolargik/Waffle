//
//  LibraryChangeCenter.swift
//  WaffleCore
//
//  Multicast change signal for the bookmark/preset library. The repositories notify
//  after every successful mutation, so Spotlight reindexing and every observing screen
//  share one stream. Replaces the old single-subscriber `libraryDidChange` closure
//  (last writer won).
//

import Foundation

@MainActor
public final class LibraryChangeCenter {

    private var continuations: [UUID: AsyncStream<Void>.Continuation] = [:]

    public init() {}

    /// A stream that yields whenever the library changes — local writes and CloudKit
    /// imports alike. Terminates automatically when the observing task ends.
    public func changes() -> AsyncStream<Void> {
        let (stream, continuation) = AsyncStream<Void>.makeStream()
        let id = UUID()
        continuations[id] = continuation
        continuation.onTermination = { [weak self] _ in
            Task { @MainActor in self?.continuations[id] = nil }
        }
        return stream
    }

    /// Notifies every active observer.
    public func notify() {
        for continuation in continuations.values {
            continuation.yield(())
        }
    }
}

// MARK: - Use case

/// Observes library changes as an `AsyncStream`.
@MainActor
public protocol ObserveLibraryChanges {
    func callAsFunction() -> AsyncStream<Void>
}

public struct ObserveLibraryChangesUseCase: ObserveLibraryChanges {
    private let center: LibraryChangeCenter
    public init(center: LibraryChangeCenter) { self.center = center }
    public func callAsFunction() -> AsyncStream<Void> {
        center.changes()
    }
}
