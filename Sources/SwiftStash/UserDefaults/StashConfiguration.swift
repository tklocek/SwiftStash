//
//  StashConfiguration.swift
//  SwiftStash
//
// Copyright (c) 2026 SwiftStash contributors
// SPDX-License-Identifier: MIT
//

import Foundation

/// Configuration for the default `UserDefaults` instance used by `@Stash` and `@Stashed`.
///
/// By default, `@Stash` and `@Stashed` use `UserDefaults.standard`. To use a custom suite
/// (e.g. for App Groups), configure once at app launch via ``SwiftStash``:
///
/// ```swift
/// SwiftStash.configureUserDefaults(suiteName: "group.com.example.app")
/// ```
///
/// Individual `@Stash` and `@Stashed` wrappers can override this default by passing
/// an explicit `userDefaults` or `store` parameter.
///
/// Thread-safety is achieved using `NSLock`, which is appropriate here because:
/// 1. Property wrapper initialisers are synchronous (cannot use async/await or Mutex on iOS 14+)
/// 2. Configuration is typically write-once at launch, read-many thereafter (low contention)
package final class StashConfiguration: @unchecked Sendable {
    
    /// Shared instance for global configuration.
    package static let shared = StashConfiguration()
    
    private let lock = NSLock()
    private var _userDefaults: UserDefaults = .standard
    
    private init() {}
    
    /// The configured default `UserDefaults` instance.
    ///
    /// Returns `UserDefaults.standard` unless overridden via ``configure(suiteName:)``.
    package var userDefaults: UserDefaults {
        lock.lock()
        defer { lock.unlock() }
        return _userDefaults
    }
    
    /// Configures the default `UserDefaults` instance with the given suite name.
    ///
    /// Must be called before any `@Stash` or `@Stashed` properties are accessed.
    /// - Parameter suiteName: The suite name for `UserDefaults` (e.g. an App Group identifier).
    package func configure(suiteName: String) {
        lock.lock()
        defer { lock.unlock() }
        
        guard !suiteName.isEmpty, let userDefaults = UserDefaults(suiteName: suiteName) else {
            assertionFailure("StashConfiguration: Failed to create UserDefaults for suite name: `\(suiteName)`")
            return
        }
        _userDefaults = userDefaults
    }
    
    /// Resets the configured `UserDefaults` instance back to `.standard`.
    ///
    /// - Important: Intended for unit tests only.
    package func resetToStandard() {
        lock.lock()
        defer { lock.unlock() }
        _userDefaults = .standard
    }
}
