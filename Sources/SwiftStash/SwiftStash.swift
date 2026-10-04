//
//  SwiftStash.swift
//  SwiftStash
//
// Copyright (c) 2026 SwiftStash contributors
// SPDX-License-Identifier: MIT
//

import Foundation

/// Central configuration point for all SwiftStash subsystems.
///
/// Use this type to configure logging, UserDefaults, and Keychain settings in one place.
/// Each subsystem is configured independently — you only need to configure what you use.
///
/// ## Quick Start
///
/// Configure once at app launch, typically in your `App.init()` or `AppDelegate`:
///
/// ```swift
/// init() {
///     // Configure logging (affects both @Stash and @SecureStash)
///     SwiftStash.configureLogging(level: .normal)
///
///     // Configure UserDefaults suite (for App Groups)
///     SwiftStash.configureUserDefaults(suiteName: "group.com.example.app")
///
///     // Configure Keychain defaults
///     SwiftStash.configureKeychain(
///         service: Bundle.main.bundleIdentifier!,
///         accessibility: .whenUnlockedThisDeviceOnly
///     )
/// }
/// ```
///
/// ## Per-Instance Overrides
///
/// Global configuration provides defaults. Individual wrappers can override:
///
/// ```swift
/// // Uses globally configured UserDefaults suite
/// @Stash(key: "username", defaultValue: "")
/// var username: String
///
/// // Overrides with a specific UserDefaults instance
/// @Stash(key: "other", defaultValue: "", userDefaults: .standard)
/// var other: String
///
/// // Uses globally configured Keychain service
/// @SecureStash(key: "token")
/// var token: String?
///
/// // Overrides accessibility for this specific item
/// @SecureStash(key: "biometricKey", accessibility: .whenPasscodeSetThisDeviceOnly)
/// var biometricKey: Data?
/// ```
///
/// ## Log Levels
///
/// - `.minimal`: Only critical errors (default, recommended for production)
/// - `.normal`: Errors + storage operations (useful for debugging)
/// - `.verbose`: Everything including encoding/decoding details (development only)
///
/// ## Privacy
///
/// SwiftStash uses Apple's privacy-preserving logging:
/// - Keys are marked as `.private` (redacted in logs)
/// - Type names are `.public` (visible for debugging)
/// - Error messages are `.public` (visible for debugging)
///
/// ## Log Categories
///
/// Logs are organized into categories in the OSLog system:
/// - `Storage.Operations` - UserDefaults operations (@Stash)
/// - `Storage.Errors` - UserDefaults errors (@Stash)
/// - `Storage.Coding` - UserDefaults encoding/decoding (@Stash)
/// - `Keychain.Operations` - Keychain operations (@SecureStash)
/// - `Keychain.Errors` - Keychain errors (@SecureStash)
/// - `Keychain.Coding` - Keychain encoding/decoding (@SecureStash)
public enum SwiftStash {

    // MARK: - Logging Configuration

    /// The current logging level for all SwiftStash operations.
    ///
    /// This affects both `@Stash` (UserDefaults) and `@SecureStash` (Keychain) wrappers.
    ///
    /// ```swift
    /// SwiftStash.logLevel = .minimal   // Errors only (default, production)
    /// SwiftStash.logLevel = .verbose   // Everything (development)
    /// ```
    public static var logLevel: StashLogLevel {
        get { Logging.logLevel }
        set { Logging.configure(level: newValue) }
    }

    /// Configures the logging level for all SwiftStash operations.
    ///
    /// Equivalent to setting ``logLevel`` directly.
    /// - Parameter level: The desired log level.
    public static func configureLogging(level: StashLogLevel) {
        Logging.configure(level: level)
    }

    // MARK: - UserDefaults Configuration

    /// Configures the application-level `UserDefaults` store used by `@Stash` and `@Stashed`.
    ///
    /// Call this once at app launch, before any wrapper is created: wrappers resolve their
    /// store at initialisation, so wrappers that already exist keep the previous store (a late
    /// call is logged as an error). Individual wrappers can override the store by passing an
    /// explicit `userDefaults` or `store` parameter.
    ///
    /// ```swift
    /// SwiftStash.configureUserDefaults(UserDefaults(suiteName: "group.com.example.app")!)
    /// ```
    ///
    /// - Important: The application level belongs to the app. A package that uses SwiftStash
    ///   configures only its own ``StashScope``, with ``configureUserDefaults(_:for:)``.
    /// - Parameter store: The store for every wrapper outside a configured scope.
    public static func configureUserDefaults(_ store: UserDefaults) {
        StashConfiguration.shared.configure(store)
    }

    /// Configures the application-level `UserDefaults` suite used by `@Stash` and `@Stashed`.
    ///
    /// Equivalent to ``configureUserDefaults(_:)`` with `UserDefaults(suiteName:)`; use it for
    /// App Groups. The same rule applies: call it before any wrapper is created.
    ///
    /// ```swift
    /// SwiftStash.configureUserDefaults(suiteName: "group.com.example.app")
    /// ```
    ///
    /// - Parameter suiteName: The suite name for `UserDefaults` (e.g. an App Group identifier).
    public static func configureUserDefaults(suiteName: String) {
        StashConfiguration.shared.configure(suiteName: suiteName)
    }

    /// Configures the `UserDefaults` store for the wrappers whose key type declares `scope`.
    ///
    /// A package calls this for its own scope; an app may call it to move a package's
    /// preferences, for example into an App Group, without moving its own. Wrappers resolve
    /// their store at initialisation, so call it before the scope's first wrapper is created.
    ///
    /// ```swift
    /// SwiftStash.configureUserDefaults(groupDefaults, for: .tipJar)
    /// ```
    ///
    /// - Parameters:
    ///   - store: The store for the scope's wrappers.
    ///   - scope: The scope to configure.
    public static func configureUserDefaults(_ store: UserDefaults, for scope: StashScope) {
        StashConfiguration.shared.configure(store, for: scope)
    }

    /// The application-level `UserDefaults` store: the one passed to
    /// ``configureUserDefaults(_:)``, or `.standard`.
    ///
    /// Use it to hand the same store to APIs that take a `UserDefaults`.
    public static var userDefaults: UserDefaults {
        StashConfiguration.shared.userDefaults
    }

    /// The `UserDefaults` store the wrappers in `scope` resolve: the scope's configured store,
    /// else the application-level one.
    /// - Parameter scope: The scope to look up.
    public static func userDefaults(for scope: StashScope) -> UserDefaults {
        StashConfiguration.shared.userDefaults(for: scope)
    }

    /// Resets the application-level store to `.standard` and removes every scope's store.
    ///
    /// Wrappers that already exist keep the store they resolved.
    public static func resetUserDefaults() {
        StashConfiguration.shared.reset()
    }

    /// Removes the store configured for `scope`, so its wrappers fall back to the
    /// application-level store.
    ///
    /// Wrappers that already exist keep the store they resolved.
    /// - Parameter scope: The scope to reset.
    public static func resetUserDefaults(for scope: StashScope) {
        StashConfiguration.shared.reset(scope)
    }

    // MARK: - Keychain Configuration

    /// Configures global defaults for `@SecureStash` property wrappers.
    ///
    /// All parameters are optional. Only provide values for settings you want to apply globally.
    /// Individual wrappers can override these settings.
    ///
    /// ```swift
    /// SwiftStash.configureKeychain(
    ///     service: Bundle.main.bundleIdentifier!,
    ///     accessibility: .whenUnlockedThisDeviceOnly
    /// )
    /// ```
    ///
    /// - Parameters:
    ///   - service: Default service identifier (typically your app's bundle ID).
    ///   - accessibility: Default keychain accessibility level.
    ///   - isSynchronizable: Default iCloud synchronization setting.
    ///   - itemClass: Default keychain item class (usually `.genericPassword`).
    public static func configureKeychain(
        service: String? = nil,
        accessibility: KeychainAccessibility? = nil,
        isSynchronizable: Bool? = nil,
        itemClass: KeychainItemClass? = nil
    ) {
        SecureStashConfiguration.shared.configure(
            service: service,
            accessibility: accessibility,
            isSynchronizable: isSynchronizable,
            itemClass: itemClass
        )
    }
}
