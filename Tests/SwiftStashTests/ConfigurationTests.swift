//
//  ConfigurationTests.swift
//  SwiftStash
//
// Copyright (c) 2026 SwiftStash contributors
// SPDX-License-Identifier: MIT
//

import Foundation
import Testing
@testable import SwiftStash

/// Tests for the global configuration entry points on `SwiftStash`.
///
/// Tests cover:
/// - `configureUserDefaults(suiteName:)` routing default-store wrappers to the suite
/// - Per-wrapper `userDefaults:` overriding the configured suite
/// - `configureKeychain(service:accessibility:)` supplying wrapper defaults
/// - Per-wrapper `service:` overriding the configured default
///
/// UserDefaults configuration is process-global, so those tests run inside exit
/// tests: the child process mutates the global freely without affecting suites
/// running in parallel. Keychain configuration tests run under the same lock as
/// every other keychain test (`runWithMockBackend`) and reset in a defer.
struct ConfigurationTests {

    @Test
    func `configureUserDefaults routes default-store Stash to the configured suite`() async {
        await #expect(processExitsWith: .success) {
            let suiteName = "swiftstash.tests.config.\(UUID().uuidString)"
            defer { UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName) }

            SwiftStash.configureUserDefaults(suiteName: suiteName)

            // No explicit userDefaults: the wrapper must resolve the configured suite.
            let stash = Stash<Int>(key: "configuredCount", defaultValue: 0)
            stash.wrappedValue = 5

            let suite = UserDefaults(suiteName: suiteName)!
            #expect(suite.integer(forKey: "configuredCount") == 5)
            #expect(stash.wrappedValue == 5)
        }
    }

    @Test
    func `Explicit userDefaults overrides the configured suite`() async {
        await #expect(processExitsWith: .success) {
            let suiteName = "swiftstash.tests.config.override.\(UUID().uuidString)"
            let explicitSuiteName = "swiftstash.tests.config.explicit.\(UUID().uuidString)"
            defer {
                UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName)
                UserDefaults(suiteName: explicitSuiteName)?.removePersistentDomain(forName: explicitSuiteName)
            }

            SwiftStash.configureUserDefaults(suiteName: suiteName)

            let explicit = UserDefaults(suiteName: explicitSuiteName)!
            let stash = Stash<Int>(key: "overriddenCount", defaultValue: 0, userDefaults: explicit)
            stash.wrappedValue = 7

            #expect(explicit.integer(forKey: "overriddenCount") == 7)
            #expect(UserDefaults(suiteName: suiteName)!.object(forKey: "overriddenCount") == nil)
        }
    }

    @Test
    func `configureKeychain supplies the default service for SecureStash`() {
        runWithMockBackend { _ in
            let globalService = makeSecureService(prefix: "config.keychain.global")
            SwiftStash.configureKeychain(service: globalService)
            defer { SecureStashConfiguration.shared.reset() }

            // No explicit service: the wrapper must fall back to the configured one.
            @SecureStash(key: "token")
            var token: String?
            token = "configured"

            #expect(SecureStashHelpers.exists(key: "token", service: globalService))
            #expect(token == "configured")
        }
    }

    @Test
    func `Explicit service overrides the configured keychain default`() {
        runWithMockBackend { _ in
            let globalService = makeSecureService(prefix: "config.keychain.global")
            let overrideService = makeSecureService(prefix: "config.keychain.override")
            SwiftStash.configureKeychain(service: globalService)
            defer { SecureStashConfiguration.shared.reset() }

            @SecureStash(key: "token", service: overrideService)
            var token: String?
            token = "override"

            #expect(SecureStashHelpers.exists(key: "token", service: overrideService))
            #expect(SecureStashHelpers.exists(key: "token", service: globalService) == false)
        }
    }

    @Test
    func `configureKeychain supplies the default accessibility for SecureStash writes`() {
        runWithMockBackend { backend in
            let service = makeSecureService(prefix: "config.keychain.accessibility")
            SwiftStash.configureKeychain(service: service, accessibility: .whenUnlockedThisDeviceOnly)
            defer { SecureStashConfiguration.shared.reset() }

            @SecureStash(key: "token")
            var token: String?
            token = "value"

            let stored = backend.accessibility(for: "token", type: .genericPassword, service: service)
            #expect(stored == .whenUnlockedThisDeviceOnly)
        }
    }
}
