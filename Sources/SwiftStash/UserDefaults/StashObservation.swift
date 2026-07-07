//
//  StashObservation.swift
//  SwiftStash
//
// Copyright (c) 2026 SwiftStash contributors
// SPDX-License-Identifier: MIT
//

import Foundation

// MARK: - Public API

public extension SwiftStash {
    /// An asynchronous stream that yields whenever the given UserDefaults key changes.
    ///
    /// Observation uses per-key KVO, so only changes to this specific key fire — including
    /// writes made by other objects (`@Stash`, `@Stashed`, `@AppStorage`, or raw
    /// `UserDefaults.set`).
    ///
    /// ```swift
    /// Task {
    ///     for await _ in SwiftStash.updates(forKey: "logLevel") {
    ///         syncLogLevel()
    ///     }
    /// }
    /// ```
    ///
    /// - Important: KVO cannot observe keys containing dots (`.`), because they are
    ///   interpreted as key paths.
    /// - Parameters:
    ///   - key: The UserDefaults key to observe.
    ///   - store: The UserDefaults instance to observe. Defaults to the globally configured instance.
    ///   - bufferingPolicy: How changes are buffered when they arrive faster than the consumer
    ///     iterates. The default, `.bufferingNewest(1)`, coalesces bursts into a single pending
    ///     signal — right for "re-read the current state" consumers. Pass `.unbounded` to receive
    ///     one element per change even under bursts.
    /// - Returns: A stream that yields once per change until the consuming task is cancelled.
    static func updates(
        forKey key: String,
        in store: UserDefaults? = nil,
        bufferingPolicy: AsyncStream<Void>.Continuation.BufferingPolicy = .bufferingNewest(1)
    ) -> AsyncStream<Void> {
        let resolvedStore = store ?? StashConfiguration.shared.userDefaults
        return AsyncStream(bufferingPolicy: bufferingPolicy) { continuation in
            let observer = UserDefaultsKeyObserver(store: resolvedStore, key: key) {
                continuation.yield()
            }
            continuation.onTermination = { _ in
                // Keeps the observer alive for the lifetime of the stream;
                // releasing it here removes the KVO registration.
                _ = observer
            }
        }
    }

    /// An asynchronous stream that yields whenever the given UserDefaults key changes,
    /// using a string-backed key type (e.g. `enum SettingsKey: String`).
    ///
    /// See ``updates(forKey:in:bufferingPolicy:)-swift.type.method`` for details.
    /// - Parameters:
    ///   - key: The key to observe; its `rawValue` is used as the UserDefaults key.
    ///   - store: The UserDefaults instance to observe. Defaults to the globally configured instance.
    ///   - bufferingPolicy: How changes are buffered when they arrive faster than the consumer
    ///     iterates. Defaults to `.bufferingNewest(1)` (bursts coalesce into one pending signal).
    /// - Returns: A stream that yields once per change until the consuming task is cancelled.
    static func updates(
        forKey key: some RawRepresentable<String>,
        in store: UserDefaults? = nil,
        bufferingPolicy: AsyncStream<Void>.Continuation.BufferingPolicy = .bufferingNewest(1)
    ) -> AsyncStream<Void> {
        updates(forKey: key.rawValue, in: store, bufferingPolicy: bufferingPolicy)
    }
}

// MARK: - KVO Observer

/// Observes a single UserDefaults key via KVO and invokes a handler on every change.
///
/// The handler is called on whatever thread performed the write. The KVO registration
/// is removed when the observer is deallocated.
package final class UserDefaultsKeyObserver: NSObject, @unchecked Sendable {
    private let store: UserDefaults
    private let key: String
    private let handler: @Sendable () -> Void

    package init(store: UserDefaults, key: String, handler: @escaping @Sendable () -> Void) {
        self.store = store
        self.key = key
        self.handler = handler
        super.init()
        unsafe store.addObserver(self, forKeyPath: key, options: [], context: nil)
    }

    deinit {
        store.removeObserver(self, forKeyPath: key)
    }

    package override func observeValue(
        forKeyPath keyPath: String?,
        of object: Any?,
        change: [NSKeyValueChangeKey: Any]?,
        context: UnsafeMutableRawPointer?
    ) {
        guard keyPath == key else { return }
        handler()
    }
}
