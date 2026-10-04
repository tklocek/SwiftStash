//
//  TestModels.swift
//  SwiftStash
//
// Copyright (c) 2026 SwiftStash contributors
// SPDX-License-Identifier: MIT
//

import Foundation
import SwiftStash

// MARK: - User Profile Models

/// Standard user profile for testing Codable storage
struct UserProfile: Codable, Equatable, Sendable {
    let name: String
    let age: Int
    let email: String
}

/// Legacy user profile for backward compatibility tests
struct LegacyUserProfile: Codable, Equatable, Sendable {
    let firstName: String
    let lastName: String
    let age: Int
}

/// Alternative profile structure for testing type mismatches
struct DifferentProfile: Codable, Equatable, Sendable {
    let firstName: String
    let lastName: String
    let initials: String
}

// MARK: - Error Testing Models

/// A type that deliberately fails during encoding to test error handling
struct FailingEncodable: Codable, Sendable {
    func encode(to encoder: any Encoder) throws {
        enum EncodingTestError: Error {
            case deliberateFailure
        }
        throw EncodingTestError.deliberateFailure
    }

    init(from decoder: any Decoder) throws {}
    init() {}
}

// MARK: - Enum Models

/// Test enum with String raw value
enum Theme: String, Sendable {
    case light
    case dark
    case system
}

/// Test enum with Int raw value
enum Priority: Int, Sendable {
    case low = 1
    case medium = 2
    case high = 3
    case critical = 4
}

// MARK: - Scopes

extension StashScope {
    /// A scope used by tests of scoped key types.
    static let testScope = StashScope("SwiftStashTests.scope")
    /// A second scope, for tests of two scopes sharing a key.
    static let otherTestScope = StashScope("SwiftStashTests.otherScope")
}

/// A key type whose keys belong to ``StashScope/testScope``.
enum TestScopedKey: String, StashScopedKey {
    case counter
    static var stashScope: StashScope { .testScope }
}

/// A key type in ``StashScope/otherTestScope`` with the same raw key as ``TestScopedKey``.
enum OtherTestScopedKey: String, StashScopedKey {
    case counter
    static var stashScope: StashScope { .otherTestScope }
}
