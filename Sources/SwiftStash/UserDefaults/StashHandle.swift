//
//  StashHandle.swift
//  SwiftStash
//
// Copyright (c) 2026 SwiftStash contributors
// SPDX-License-Identifier: MIT
//

import Foundation

/// A handle to a `@Stash` property, exposed through its projected value (`$property`).
///
/// The handle answers questions the wrapped value alone cannot:
///
/// ```swift
/// @Stash(key: "launchCount", defaultValue: 0)
/// var launchCount: Int
///
/// $launchCount.exists      // false until something is written
/// $launchCount.remove()    // deletes the key; reads fall back to the default
/// $launchCount.key         // "launchCount"
///
/// for await count in $launchCount.updates {
///     print("launchCount is now \(count)")
/// }
/// ```
public struct StashHandle<Value: Sendable>: Sendable {
    private let storage: AnyUserDefaultsStorage<Value>

    package init(storage: AnyUserDefaultsStorage<Value>) {
        self.storage = storage
    }

    /// The UserDefaults key this stash reads and writes.
    public var key: String {
        storage.key
    }

    /// Whether a value is currently stored under the key.
    ///
    /// `false` means reads return the default value. This distinguishes
    /// "stored value equals the default" from "nothing stored".
    public var exists: Bool {
        storage.store.object(forKey: storage.key) != nil
    }

    /// Removes the stored value from UserDefaults.
    ///
    /// Subsequent reads return the default value (or `nil` for optional stashes).
    public func remove() {
        Logging.logOperation("REMOVE (via handle)", key: storage.key, type: String(describing: Value.self))
        storage.store.removeObject(forKey: storage.key)
    }

    /// An asynchronous stream of values for this key.
    ///
    /// Yields the current value immediately, then the freshly read value after every
    /// change to the key — including writes made by other objects (`@Stash`, `@Stashed`,
    /// `@AppStorage`, or raw `UserDefaults.set`).
    ///
    /// Uses the default buffering policy of ``updates(bufferingPolicy:)``:
    /// `.bufferingNewest(1)`, so a consumer that falls behind sees the latest value
    /// rather than replaying every intermediate one.
    ///
    /// - Important: KVO cannot observe keys containing dots (`.`), because they are
    ///   interpreted as key paths.
    public var updates: AsyncStream<Value> {
        updates()
    }

    /// An asynchronous stream of values for this key, with an explicit buffering policy.
    ///
    /// See ``updates`` for the yield semantics.
    ///
    /// - Parameter bufferingPolicy: How values are buffered when changes arrive faster than
    ///   the consumer iterates. The default, `.bufferingNewest(1)`, keeps only the latest
    ///   value — right for state synchronisation. Pass `.unbounded` to replay every
    ///   intermediate value instead.
    public func updates(
        bufferingPolicy: AsyncStream<Value>.Continuation.BufferingPolicy = .bufferingNewest(1)
    ) -> AsyncStream<Value> {
        let storage = self.storage
        return AsyncStream(bufferingPolicy: bufferingPolicy) { continuation in
            continuation.yield(storage.get())
            let observer = UserDefaultsKeyObserver(store: storage.store, key: storage.key) {
                continuation.yield(storage.get())
            }
            continuation.onTermination = { _ in
                // Keeps the observer alive for the lifetime of the stream;
                // releasing it here removes the KVO registration.
                _ = observer
            }
        }
    }
}
