//
//  SecureStashHandleTests.swift
//  SwiftStash
//
// Copyright (c) 2026 SwiftStash contributors
// SPDX-License-Identifier: MIT
//

import Foundation
import Testing
@testable import SwiftStash

/// Tests for the @SecureStash projected value (SecureStashHandle).
///
/// Tests cover:
/// - Key exposure
/// - exists as a decode-free presence probe
/// - remove() semantics, including idempotence
struct SecureStashHandleTests {

    @Test
    func `Handle exposes the wrapper key`() {
        runWithMockBackend { _ in
            let service = makeSecureService(prefix: "secure.handle.key")

            @SecureStash(key: "authToken", service: service)
            var token: String?

            #expect($token.key == "authToken")
        }
    }

    @Test
    func `exists is false before a write and true after`() {
        runWithMockBackend { _ in
            let service = makeSecureService(prefix: "secure.handle.exists")

            @SecureStash(key: "token", service: service)
            var token: String?

            #expect($token.exists == false)

            token = "stored"

            #expect($token.exists)
        }
    }

    @Test
    func `remove deletes the item and reads fall back to nil`() {
        runWithMockBackend { _ in
            let service = makeSecureService(prefix: "secure.handle.remove")

            @SecureStash(key: "token", service: service)
            var token: String?
            token = "to-remove"

            $token.remove()

            #expect(token == nil)
            #expect($token.exists == false)
            #expect(SecureStashHelpers.exists(key: "token", service: service) == false)
        }
    }

    @Test
    func `remove on an absent item is a no-op`() {
        runWithMockBackend { _ in
            let service = makeSecureService(prefix: "secure.handle.remove.absent")

            @SecureStash(key: "token", service: service)
            var token: String?

            $token.remove()

            #expect(token == nil)
            #expect($token.exists == false)
        }
    }

    @Test
    func `exists reports true for a payload the coder cannot decode`() {
        runWithMockBackend { backend in
            let service = makeSecureService(prefix: "secure.handle.undecodable")
            backend.seed(
                Data("not json".utf8),
                for: "profile",
                type: .genericPassword,
                synchronizable: false,
                service: service
            )

            struct Profile: Codable, Sendable, Equatable {
                var name: String
            }

            @SecureStash(codable: "profile", service: service)
            var profile: Profile?

            // The read fails to decode, but the item is present.
            #expect(profile == nil)
            #expect($profile.exists)
        }
    }

    @Test
    func `exists finds items regardless of synchronizable state`() {
        runWithMockBackend { backend in
            let service = makeSecureService(prefix: "secure.handle.syncany")
            backend.seed(
                Data("synced".utf8),
                for: "token",
                type: .genericPassword,
                synchronizable: true,
                service: service
            )

            @SecureStash(key: "token", service: service)
            var token: String?

            #expect($token.exists)
        }
    }
}
