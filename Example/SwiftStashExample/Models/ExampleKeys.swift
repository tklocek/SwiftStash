//
//  ExampleKeys.swift
//  SwiftStashExample
//
// Copyright (c) 2026 SwiftStash contributors
// SPDX-License-Identifier: MIT
//

import Foundation

/// Keychain configuration shared by every screen that touches the Keychain.
enum ExampleKeychain {
    /// The service identifier passed to `SwiftStash.configureKeychain(service:)` at launch.
    /// In a real app this is typically `Bundle.main.bundleIdentifier!`.
    static let service = "com.swiftstash.example"

    /// A second service used by the per-wrapper override demos. Items stored here are
    /// invisible to `allKeys(service:)` queries against the main service.
    static let legacyService = "com.swiftstash.example.legacy"
}

/// Typed keys for the values shared across the Adoption Patterns screens.
///
/// Every wrapper initialiser accepts any `RawRepresentable<String>` key, so a plain
/// `String`-backed enum is all that is needed — no protocol conformances, no registration.
/// All screens in the Adoption section read and write these same keys, which makes it easy
/// to verify that the architecture style never changes what is persisted.
///
/// Two deliberate choices worth copying into your own app:
/// - **No dots in raw values.** Keys containing `.` can be stored but not observed,
///   because KVO interprets them as key paths (see the Observation section).
/// - The bare dot spelling `@Stash(key: .username)` is not possible with the generic
///   `some RawRepresentable<String>` parameters; if you want it, keep a thin concrete
///   initialiser extension in your app that takes this enum directly.
enum SharedKey: String {
    // UserDefaults (@Stash / @Stashed)
    case username
    case launchCount
    case theme
    case profile

    // Keychain (@SecureStash)
    case authToken
    case credentials
}
