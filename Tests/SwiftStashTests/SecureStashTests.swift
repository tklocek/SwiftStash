//
//  SecureStashTests.swift
//  SwiftStash
//
// Copyright (c) 2026 SwiftStash contributors
// SPDX-License-Identifier: MIT
//

import Foundation
import Testing
@testable import SwiftStash

/// Core functionality tests for @SecureStash property wrapper.
///
/// Tests cover:
/// - Optional String, Data, and Codable storage
/// - Persistence across wrapper instances
/// - Key deletion semantics for optional values
/// - Service and item class isolation
/// - Helper APIs (exists, allKeys, clearAll)
struct SecureStashTests {

    // MARK: - String Storage

    @Test
    func `Optional String returns nil when key is absent`() {
        runWithMockBackend { _ in
            let service = makeSecureService(prefix: "secure.string.absent")

            @SecureStash(key: "token", service: service)
            var token: String?

            #expect(token == nil)
        }
    }

    @Test
    func `Optional String persists across wrapper instances`() {
        runWithMockBackend { _ in
            let service = makeSecureService(prefix: "secure.string.persist")

            @SecureStash(key: "token", service: service)
            var token: String?
            token = "Hello Keychain"

            @SecureStash(key: "token", service: service)
            var reloadedToken: String?

            #expect(reloadedToken == "Hello Keychain")
        }
    }

    @Test
    func `Optional String deletes keychain item when set to nil`() {
        runWithMockBackend { _ in
            let service = makeSecureService(prefix: "secure.string.delete")

            @SecureStash(key: "token", service: service)
            var token: String?
            token = "to-delete"

            #expect(SecureStashHelpers.exists(key: "token", service: service))

            token = nil

            #expect(SecureStashHelpers.exists(key: "token", service: service) == false)
        }
    }

    @Test
    func `String read returns nil for non-UTF8 payload`() {
        runWithMockBackend { backend in
            let service = makeSecureService(prefix: "secure.string.invalidutf8")
            backend.seed(
                Data([0xFF, 0xFE, 0xFD]),
                for: "token",
                type: .genericPassword,
                synchronizable: false,
                service: service
            )

            @SecureStash(key: "token", service: service)
            var token: String?

            #expect(token == nil)
        }
    }

    // MARK: - Data Storage

    @Test
    func `Data persists across wrapper instances`() {
        runWithMockBackend { _ in
            let service = makeSecureService(prefix: "secure.data.persist")
            let payload = Data("secret-bytes".utf8)

            @SecureStash(key: "blob", service: service)
            var blob: Data?
            blob = payload

            @SecureStash(key: "blob", service: service)
            var reloadedBlob: Data?

            #expect(reloadedBlob == payload)
        }
    }

    // MARK: - Codable Storage

    @Test
    func `Optional Codable persists across wrapper instances`() {
        runWithMockBackend { _ in
            let service = makeSecureService(prefix: "secure.codable.persist")
            let profile = UserProfile(name: "Alice", age: 30, email: "alice@example.com")

            @SecureStash(codable: "profile", service: service)
            var storedProfile: UserProfile?
            storedProfile = profile

            @SecureStash(codable: "profile", service: service)
            var reloadedProfile: UserProfile?

            #expect(reloadedProfile == profile)
        }
    }

    @Test
    func `Optional Int uses the Codable initializer`() {
        runWithMockBackend { _ in
            let service = makeSecureService(prefix: "secure.codable.int")

            let storedValue = SecureStash<Int?>(codable: "userId", service: service)
            storedValue.wrappedValue = 42

            let reloadedValue = SecureStash<Int?>(codable: "userId", service: service)
            #expect(reloadedValue.wrappedValue == 42)
        }
    }

    @Test
    func `Optional Codable returns nil when stored payload is corrupted`() {
        runWithMockBackend { backend in
            let service = makeSecureService(prefix: "secure.codable.corrupted")
            backend.seed(
                Data("not-valid-json".utf8),
                for: "profile",
                type: .genericPassword,
                synchronizable: false,
                service: service
            )

            @SecureStash(codable: "profile", service: service)
            var profile: UserProfile?

            #expect(profile == nil)
        }
    }

    @Test
    func `Encoding failure creates no keychain item for an absent key`() {
        runWithMockBackend { _ in
            let service = makeSecureService(prefix: "secure.codable.encodefails")

            @SecureStash(codable: "failing", service: service)
            var value: FailingEncodable?

            value = FailingEncodable()

            #expect(SecureStashHelpers.exists(key: "failing", service: service) == false)
        }
    }

    @Test
    func `Encoding failure leaves the previously stored payload untouched`() throws {
        try runWithMockBackend { backend in
            let service = makeSecureService(prefix: "secure.codable.encodefails.preserve")
            let previousPayload = Data("last-known-good".utf8)
            backend.seed(
                previousPayload,
                for: "failing",
                type: .genericPassword,
                synchronizable: false,
                service: service
            )

            @SecureStash(codable: "failing", service: service)
            var value: FailingEncodable?

            value = FailingEncodable()

            let stored = try KeychainManager(service: service).load(for: "failing", with: .genericPassword)
            #expect(stored == previousPayload)
        }
    }

    @Test
    func `Custom encoder and decoder round trip date payload`() {
        runWithMockBackend { _ in
            struct DateContainer: Codable, Equatable {
                let timestamp: Date
            }

            let service = makeSecureService(prefix: "secure.codable.customcoder")

            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601

            let expected = DateContainer(timestamp: Date(timeIntervalSince1970: 1_234_567_890))

            @SecureStash(codable: "container", service: service, encoder: encoder, decoder: decoder)
            var container: DateContainer?
            container = expected

            @SecureStash(codable: "container", service: service, encoder: encoder, decoder: decoder)
            var reloadedContainer: DateContainer?

            #expect(reloadedContainer == expected)
        }
    }

    // MARK: - Isolation

    @Test
    func `Same key in different services stores independent values`() {
        runWithMockBackend { _ in
            let serviceA = makeSecureService(prefix: "secure.service.a")
            let serviceB = makeSecureService(prefix: "secure.service.b")

            @SecureStash(key: "sharedKey", service: serviceA)
            var valueInA: String?

            @SecureStash(key: "sharedKey", service: serviceB)
            var valueInB: String?

            valueInA = "A"
            valueInB = "B"

            #expect(valueInA == "A")
            #expect(valueInB == "B")
        }
    }

    @Test
    func `Internet password values are isolated by domain`() {
        runWithMockBackend { _ in
            let service = makeSecureService(prefix: "secure.internet.domain")

            @SecureStash(
                key: "username",
                service: service,
                itemClass: .internetPassword(domain: "api.example.com")
            )
            var apiPassword: String?

            @SecureStash(
                key: "username",
                service: service,
                itemClass: .internetPassword(domain: "other.example.com")
            )
            var otherPassword: String?

            apiPassword = "secret"

            #expect(apiPassword == "secret")
            #expect(otherPassword == nil)
        }
    }

    @Test
    func `Internet password identity ignores the service`() {
        runWithMockBackend { _ in
            // Mirrors live SecItem semantics: internet-password identity is
            // account + domain; kSecAttrService never enters the query, so two
            // different services with the same key and domain hit the same item.
            let itemClass = KeychainItemClass.internetPassword(domain: "api.example.com")

            @SecureStash(
                key: "username",
                service: makeSecureService(prefix: "secure.internet.service.a"),
                itemClass: itemClass
            )
            var passwordViaServiceA: String?

            @SecureStash(
                key: "username",
                service: makeSecureService(prefix: "secure.internet.service.b"),
                itemClass: itemClass
            )
            var passwordViaServiceB: String?

            passwordViaServiceA = "shared-item"

            #expect(passwordViaServiceB == "shared-item")
        }
    }

    @Test
    func `Generic and internet password item classes do not collide for same key`() {
        runWithMockBackend { _ in
            let service = makeSecureService(prefix: "secure.itemclass.isolation")

            @SecureStash(key: "credential", service: service)
            var genericValue: String?

            @SecureStash(
                key: "credential",
                service: service,
                itemClass: .internetPassword(domain: "api.example.com")
            )
            var internetValue: String?

            genericValue = "generic"
            internetValue = "internet"

            #expect(genericValue == "generic")
            #expect(internetValue == "internet")
        }
    }

    // MARK: - Helpers

    @Test
    func `exists reports key presence accurately`() {
        runWithMockBackend { _ in
            let service = makeSecureService(prefix: "secure.helpers.exists")

            #expect(SecureStashHelpers.exists(key: "token", service: service) == false)

            @SecureStash(key: "token", service: service)
            var token: String?
            token = "present"

            #expect(SecureStashHelpers.exists(key: "token", service: service))

            token = nil
            #expect(SecureStashHelpers.exists(key: "token", service: service) == false)
        }
    }

    @Test
    func `exists finds items regardless of synchronizable state`() {
        runWithMockBackend { backend in
            let service = makeSecureService(prefix: "secure.helpers.syncany")
            backend.seed(
                Data("synced".utf8),
                for: "token",
                type: .genericPassword,
                synchronizable: true,
                service: service
            )

            #expect(SecureStashHelpers.exists(key: "token", service: service))
        }
    }

    @Test
    func `Writes to an existing item re-apply the wrapper accessibility`() {
        runWithMockBackend { backend in
            let service = makeSecureService(prefix: "secure.accessibility.reapply")

            // An older app version stored the item with a different accessibility.
            @SecureStash(key: "token", service: service, accessibility: .whenUnlockedThisDeviceOnly)
            var oldToken: String?
            oldToken = "old"
            #expect(backend.accessibility(for: "token", type: .genericPassword, service: service) == .whenUnlockedThisDeviceOnly)

            // A wrapper with the current accessibility converges the item at its next write.
            @SecureStash(key: "token", service: service, accessibility: .afterFirstUnlockThisDeviceOnly)
            var currentToken: String?
            currentToken = "new"

            #expect(backend.accessibility(for: "token", type: .genericPassword, service: service) == .afterFirstUnlockThisDeviceOnly)
            #expect(currentToken == "new")
        }
    }

    @Test
    func `Wrapper reads an item saved with a different synchronizable state`() {
        runWithMockBackend { backend in
            let service = makeSecureService(prefix: "secure.syncany.read")
            backend.seed(
                Data("synced-secret".utf8),
                for: "token",
                type: .genericPassword,
                synchronizable: true,
                service: service
            )

            @SecureStash(key: "token", service: service, isSynchronizable: false)
            var token: String?

            #expect(token == "synced-secret")
        }
    }

    @Test
    func `allKeys and clearAll manage service-scoped keys`() {
        runWithMockBackend { _ in
            let service = makeSecureService(prefix: "secure.helpers.keys")
            let otherService = makeSecureService(prefix: "secure.helpers.keys.other")

            @SecureStash(key: "k1", service: service)
            var v1: String?
            @SecureStash(key: "k2", service: service)
            var v2: String?
            @SecureStash(key: "k3", service: otherService)
            var v3: String?

            v1 = "one"
            v2 = "two"
            v3 = "three"

            let keysBeforeClear = SecureStashHelpers.allKeys(service: service)
            #expect(keysBeforeClear.contains("k1"))
            #expect(keysBeforeClear.contains("k2"))
            #expect(keysBeforeClear.contains("k3") == false)

            let deletedCount = SecureStashHelpers.clearAll(service: service)

            #expect(deletedCount == 2)
            #expect(SecureStashHelpers.exists(key: "k1", service: service) == false)
            #expect(SecureStashHelpers.exists(key: "k2", service: service) == false)
            // Other services are untouched.
            #expect(SecureStashHelpers.exists(key: "k3", service: otherService))
        }
    }

    @Test
    func `SecureStash routes operations and errors to Keychain logging`() {
        runWithMockBackend { backend in
            let key = "logging-route"
            let service = makeSecureService(prefix: "secure.logging.route")
            let collector = LoggingEventCollector()

            Logging.setEventObserver { event in
                guard event.key == key else { return }
                collector.append(event)
            }
            defer {
                Logging.setEventObserver(nil)
            }

            @SecureStash(key: key, service: service)
            var token: String?

            token = "secret"
            _ = token
            token = nil

            backend.seed(
                Data([0xFF]),
                for: key,
                type: .genericPassword,
                synchronizable: false,
                service: service
            )
            _ = token

            let events = collector.events
            #expect(events.isEmpty == false)
            #expect(events.contains { $0.kind == .operation })
            #expect(events.contains { $0.kind == .coding })
            #expect(events.contains { $0.kind == .error })
            #expect(events.allSatisfy { $0.storageType == .keychain })
        }
    }

    @Test
    func `SecureStash requires a service`() async {
        await #expect(processExitsWith: .failure) {
            SecureStashConfiguration.shared.reset()
            _ = SecureStash<String?>(key: "missing-service")
        }
    }

    @Test
    func `Synchronizable items reject device-only accessibility`() async {
        await #expect(processExitsWith: .failure) {
            _ = SecureStash<String?>(
                key: "invalid-sync-accessibility",
                service: "swiftstash.tests.invalid-sync-accessibility",
                accessibility: .whenUnlockedThisDeviceOnly,
                isSynchronizable: true
            )
        }
    }
}

