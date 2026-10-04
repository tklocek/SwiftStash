//
//  StashConfiguration.swift
//  SwiftStash
//
// Copyright (c) 2026 SwiftStash contributors
// SPDX-License-Identifier: MIT
//

import Foundation

/// Configuration for the default `UserDefaults` instances used by `@Stash` and `@Stashed`.
///
/// By default, `@Stash` and `@Stashed` use `UserDefaults.standard`. The application can
/// configure a different store, and each ``StashScope`` can be given a store of its own,
/// via ``SwiftStash``:
///
/// ```swift
/// SwiftStash.configureUserDefaults(suiteName: "group.com.example.app")
/// SwiftStash.configureUserDefaults(tipJarDefaults, for: .tipJar)
/// ```
///
/// Wrappers resolve their store once, at initialisation, so configuration must happen
/// before the first wrapper is created. Individual `@Stash` and `@Stashed` wrappers can
/// override the configured store by passing an explicit `userDefaults` or `store` parameter.
///
/// Thread-safety is achieved using `NSLock`, which is appropriate here because:
/// 1. Property wrapper initialisers are synchronous (cannot use async/await or Mutex on iOS 14+)
/// 2. Configuration is typically write-once at launch, read-many thereafter (low contention)
package final class StashConfiguration: @unchecked Sendable {

    /// Shared instance for global configuration.
    package static let shared = StashConfiguration()

    private let lock = NSLock()
    private var _userDefaults: UserDefaults = .standard
    private var scopedUserDefaults: [StashScope: UserDefaults] = [:]
    /// Set once any wrapper has resolved its store from this configuration; a later
    /// configure call cannot reach those wrappers, which is worth a diagnostic.
    private var hasResolved = false

    private init() {}

    /// The configured application-level `UserDefaults` instance.
    ///
    /// Returns `UserDefaults.standard` unless overridden via ``configure(_:)``.
    package var userDefaults: UserDefaults {
        userDefaults(for: nil)
    }

    /// The store a wrapper in `scope` resolves: the scope's configured store, else the
    /// application-level store.
    /// - Parameter scope: The wrapper's scope, or `nil` for the application level.
    package func userDefaults(for scope: StashScope?) -> UserDefaults {
        withLock { lookUp(scope) }
    }

    /// Resolves the store for a wrapper being created, and records that a wrapper has
    /// captured the configuration (see ``configure(_:)``).
    /// - Parameter scope: The wrapper's scope, or `nil` for the application level.
    package func resolveUserDefaults(for scope: StashScope?) -> UserDefaults {
        withLock {
            hasResolved = true
            return lookUp(scope)
        }
    }

    /// Configures the application-level `UserDefaults` instance.
    /// - Parameter userDefaults: The store for wrappers outside any configured scope.
    package func configure(_ userDefaults: UserDefaults) {
        let configuredLate = withLock {
            _userDefaults = userDefaults
            return hasResolved
        }
        if configuredLate {
            logLateConfiguration()
        }
    }

    /// Configures the `UserDefaults` instance for one scope.
    /// - Parameters:
    ///   - userDefaults: The store for wrappers whose key type declares `scope`.
    ///   - scope: The scope to configure.
    package func configure(_ userDefaults: UserDefaults, for scope: StashScope) {
        let configuredLate = withLock {
            scopedUserDefaults[scope] = userDefaults
            return hasResolved
        }
        if configuredLate {
            logLateConfiguration()
        }
    }

    /// Configures the application-level `UserDefaults` instance with the given suite name.
    ///
    /// Must be called before any `@Stash` or `@Stashed` properties are created.
    /// - Parameter suiteName: The suite name for `UserDefaults` (e.g. an App Group identifier).
    package func configure(suiteName: String) {
        guard !suiteName.isEmpty, let userDefaults = UserDefaults(suiteName: suiteName) else {
            assertionFailure("StashConfiguration: Failed to create UserDefaults for suite name: `\(suiteName)`")
            return
        }
        configure(userDefaults)
    }

    /// Resets the application level to `.standard` and removes every scope's store.
    package func reset() {
        withLock {
            _userDefaults = .standard
            scopedUserDefaults.removeAll()
            hasResolved = false
        }
    }

    /// Removes the store configured for `scope`, so it falls back to the application level.
    /// - Parameter scope: The scope to reset.
    package func reset(_ scope: StashScope) {
        withLock {
            scopedUserDefaults[scope] = nil
        }
    }

    /// Must be called with `lock` held.
    private func lookUp(_ scope: StashScope?) -> UserDefaults {
        if let scope, let scoped = scopedUserDefaults[scope] {
            return scoped
        }
        return _userDefaults
    }

    private func withLock<T>(_ body: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return body()
    }

    private func logLateConfiguration() {
        Logging.logError(
            "UserDefaults configured after a wrapper had already resolved its store; existing wrappers keep the previous store"
        )
    }
}
