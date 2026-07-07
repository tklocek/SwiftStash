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

    /// Configures the default `UserDefaults` suite used by `@Stash` and `@Stashed`.
    ///
    /// Call this once at app launch to use a custom suite (e.g. for App Groups).
    /// Individual wrappers can override by passing an explicit `userDefaults` or `store` parameter.
    ///
    /// ```swift
    /// SwiftStash.configureUserDefaults(suiteName: "group.com.example.app")
    /// ```
    ///
    /// - Parameter suiteName: The suite name for `UserDefaults` (e.g. an App Group identifier).
    public static func configureUserDefaults(suiteName: String) {
        StashConfiguration.shared.configure(suiteName: suiteName)
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
