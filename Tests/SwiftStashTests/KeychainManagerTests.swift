//
//  KeychainManagerTests.swift
//  SwiftStash
//
// Copyright (c) 2026 SwiftStash contributors
// SPDX-License-Identifier: MIT
//

import Foundation
import Testing
@testable import SwiftStash

/// CRUD tests for `KeychainManager`, running against the in-memory backend.
///
/// Tests cover:
/// - Data save/load round trips and `.duplicateItem` on re-save
/// - `.itemNotFound` on load/update of absent items
/// - Update semantics, including items saved with a different synchronizable state
/// - Delete idempotence
/// - Codable save/load/update and `.decodeFailure`
///
/// The crypto surface (biometric items, SecKey APIs) talks to the Security framework
/// directly and is validated via the example app on device; see `KeychainCryptoTests`
/// for its keychain-free parts.
struct KeychainManagerTests {

    private func makeManager(prefix: String) -> KeychainManager {
        KeychainManager(service: makeSecureService(prefix: prefix))
    }

    // MARK: - Data CRUD

    @Test
    func `Data save and load round trip`() throws {
        try runWithMockBackend { _ in
            let manager = makeManager(prefix: "manager.data.roundtrip")
            let payload = Data("secret-bytes".utf8)

            try manager.save(payload, for: "token", with: .genericPassword)

            let loaded = try manager.load(for: "token", with: .genericPassword)
            #expect(loaded == payload)
        }
    }

    @Test
    func `Save throws duplicateItem when the key already exists`() throws {
        try runWithMockBackend { _ in
            let manager = makeManager(prefix: "manager.data.duplicate")

            try manager.save(Data("first".utf8), for: "token", with: .genericPassword)

            #expect(throws: KeychainError.duplicateItem) {
                try manager.save(Data("second".utf8), for: "token", with: .genericPassword)
            }
        }
    }

    @Test
    func `Load throws itemNotFound for an absent key`() {
        runWithMockBackend { _ in
            let manager = makeManager(prefix: "manager.data.absent")

            #expect(throws: KeychainError.itemNotFound) {
                _ = try manager.load(for: "missing", with: .genericPassword)
            }
        }
    }

    @Test
    func `Update replaces the stored value`() throws {
        try runWithMockBackend { _ in
            let manager = makeManager(prefix: "manager.data.update")

            try manager.save(Data("old".utf8), for: "token", with: .genericPassword)
            try manager.update(Data("new".utf8), for: "token", with: .genericPassword)

            let loaded = try manager.load(for: "token", with: .genericPassword)
            #expect(loaded == Data("new".utf8))
        }
    }

    @Test
    func `Update throws itemNotFound for an absent key`() {
        runWithMockBackend { _ in
            let manager = makeManager(prefix: "manager.data.update.absent")

            #expect(throws: KeychainError.itemNotFound) {
                try manager.update(Data("value".utf8), for: "missing", with: .genericPassword)
            }
        }
    }

    @Test
    func `Update finds an item saved with a different synchronizable state`() throws {
        try runWithMockBackend { backend in
            let service = makeSecureService(prefix: "manager.data.update.syncany")
            let manager = KeychainManager(service: service)
            backend.seed(
                Data("synced".utf8),
                for: "token",
                type: .genericPassword,
                synchronizable: true,
                service: service
            )

            try manager.update(Data("updated".utf8), for: "token", with: .genericPassword)

            let loaded = try manager.load(for: "token", with: .genericPassword)
            #expect(loaded == Data("updated".utf8))
        }
    }

    @Test
    func `Update with nil accessibility preserves the stored level`() throws {
        try runWithMockBackend { backend in
            let service = makeSecureService(prefix: "manager.data.accessibility.preserve")
            let manager = KeychainManager(service: service)

            try manager.save(
                Data("old".utf8),
                for: "token",
                with: .genericPassword,
                accessibility: .whenUnlocked
            )
            #expect(backend.accessibility(for: "token", type: .genericPassword, service: service) == .whenUnlocked)

            try manager.update(Data("new".utf8), for: "token", with: .genericPassword, accessibility: nil)

            #expect(backend.accessibility(for: "token", type: .genericPassword, service: service) == .whenUnlocked)
        }
    }

    @Test
    func `Update with explicit accessibility re-applies it`() throws {
        try runWithMockBackend { backend in
            let service = makeSecureService(prefix: "manager.data.accessibility.reapply")
            let manager = KeychainManager(service: service)

            try manager.save(
                Data("old".utf8),
                for: "token",
                with: .genericPassword,
                accessibility: .whenUnlocked
            )

            try manager.update(
                Data("new".utf8),
                for: "token",
                with: .genericPassword,
                accessibility: .afterFirstUnlock
            )

            #expect(backend.accessibility(for: "token", type: .genericPassword, service: service) == .afterFirstUnlock)
        }
    }

    @Test
    func `Delete removes the item and is idempotent`() throws {
        try runWithMockBackend { _ in
            let manager = makeManager(prefix: "manager.data.delete")

            try manager.save(Data("value".utf8), for: "token", with: .genericPassword)
            try manager.delete(for: "token", with: .genericPassword)

            #expect(throws: KeychainError.itemNotFound) {
                _ = try manager.load(for: "token", with: .genericPassword)
            }

            // Deleting an absent item is not an error.
            try manager.delete(for: "token", with: .genericPassword)
        }
    }

    // MARK: - Codable CRUD

    @Test
    func `Codable save and load round trip`() throws {
        try runWithMockBackend { _ in
            let manager = makeManager(prefix: "manager.codable.roundtrip")
            let profile = UserProfile(name: "Alice", age: 30, email: "alice@example.com")

            try manager.save(profile, for: "profile", with: .genericPassword, accessibility: nil, isSynchronizable: nil)

            let loaded: UserProfile = try manager.load(for: "profile", with: .genericPassword)
            #expect(loaded == profile)
        }
    }

    @Test
    func `Codable update replaces the stored value`() throws {
        try runWithMockBackend { _ in
            let manager = makeManager(prefix: "manager.codable.update")
            let original = UserProfile(name: "Alice", age: 30, email: "alice@example.com")
            let replacement = UserProfile(name: "Bob", age: 41, email: "bob@example.com")

            try manager.save(original, for: "profile", with: .genericPassword, accessibility: nil, isSynchronizable: nil)
            try manager.update(replacement, for: "profile", with: .genericPassword)

            let loaded: UserProfile = try manager.load(for: "profile", with: .genericPassword)
            #expect(loaded == replacement)
        }
    }

    @Test
    func `Codable load throws decodeFailure for an undecodable payload`() throws {
        runWithMockBackend { backend in
            let service = makeSecureService(prefix: "manager.codable.corrupted")
            let manager = KeychainManager(service: service)
            backend.seed(
                Data("not-valid-json".utf8),
                for: "profile",
                type: .genericPassword,
                synchronizable: false,
                service: service
            )

            #expect(throws: KeychainError.decodeFailure) {
                let _: UserProfile = try manager.load(for: "profile", with: .genericPassword)
            }
        }
    }

    @Test
    func `Custom encoder and decoder round trip a date payload`() throws {
        try runWithMockBackend { _ in
            struct DateContainer: Codable, Equatable {
                let timestamp: Date
            }

            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601

            let manager = KeychainManager(
                service: makeSecureService(prefix: "manager.codable.customcoder"),
                encoder: encoder,
                decoder: decoder
            )
            let expected = DateContainer(timestamp: Date(timeIntervalSince1970: 1_234_567_890))

            try manager.save(expected, for: "container", with: .genericPassword, accessibility: nil, isSynchronizable: nil)

            let loaded: DateContainer = try manager.load(for: "container", with: .genericPassword)
            #expect(loaded == expected)
        }
    }

    // MARK: - Interop with @SecureStash

    @Test
    func `Manager reads an item written by a SecureStash wrapper`() throws {
        try runWithMockBackend { _ in
            let service = makeSecureService(prefix: "manager.interop")
            let manager = KeychainManager(service: service)

            @SecureStash(key: "token", service: service)
            var token: String?
            token = "wrapper-written"

            let loaded = try manager.load(for: "token", with: .genericPassword)
            #expect(String(data: loaded, encoding: .utf8) == "wrapper-written")
        }
    }
}
