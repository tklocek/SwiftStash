//
//  ExampleModels.swift
//  SwiftStashExample
//
// Copyright (c) 2026 SwiftStash contributors
// SPDX-License-Identifier: MIT
//

import Foundation

/// A raw-representable enum stored via the primitive initialiser.
///
/// `@Stash`/`@Stashed` persist the raw value directly (here the `String`), not JSON —
/// exactly what `@AppStorage` does, so the two can read each other's keys.
enum Theme: String, CaseIterable, Codable, Sendable {
    case system
    case light
    case dark
}

/// A `Codable` model stored as JSON `Data` via the `codable:` initialiser label.
///
/// `@AppStorage` cannot store this type at all; with SwiftStash the only difference
/// from a primitive is the initialiser label.
struct UserProfile: Codable, Equatable, Sendable {
    var name: String
    var email: String
    var age: Int

    static let empty = UserProfile(name: "", email: "", age: 0)
    static let sample = UserProfile(name: "John Appleseed", email: "john@example.com", age: 30)
}

/// A `Codable` secret stored in the Keychain via `@SecureStash(codable:)` — JSON-encoded,
/// like `@Stash(codable:)`, but backed by the Keychain instead of UserDefaults.
struct Credentials: Codable, Equatable, Sendable {
    var username: String
    var password: String

    static let sample = Credentials(username: "user@example.com", password: "correct-horse-battery")
}

/// A `Codable` model with a `Date` — the case where custom coder strategies matter:
/// the default `JSONEncoder` writes dates as seconds since 2001, an ISO-8601 strategy
/// writes a human-readable timestamp that other systems can parse.
struct SyncCheckpoint: Codable, Equatable, Sendable {
    var deviceName: String
    var lastSync: Date

    static let initial = SyncCheckpoint(deviceName: "never synced", lastSync: Date(timeIntervalSince1970: 0))
}
