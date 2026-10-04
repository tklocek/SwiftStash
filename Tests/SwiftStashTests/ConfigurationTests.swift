//
//  ConfigurationTests.swift
//  SwiftStash
//
// Copyright (c) 2026 SwiftStash contributors
// SPDX-License-Identifier: MIT
//

import Foundation
import Testing
import SwiftUI
@testable import SwiftStash
import SwiftStashUI

/// Tests for the global configuration entry points on `SwiftStash`.
///
/// Tests cover:
/// - `configureUserDefaults(suiteName:)` routing default-store wrappers to the suite
/// - Per-wrapper `userDefaults:` overriding the configured suite
/// - `configureUserDefaults(_:)` taking an instance, honoured by every wrapper kind
/// - Scoped stores (`configureUserDefaults(_:for:)`), their fallback, and the resolution
///   chain: explicit store > environment > scope's store > application store > `.standard`
/// - Reading and resetting the configured stores
/// - `configureKeychain(service:accessibility:)` supplying wrapper defaults
/// - Per-wrapper `service:` overriding the configured default
///
/// UserDefaults configuration is process-global, so those tests run inside exit
/// tests: the child process mutates the global freely without affecting suites
/// running in parallel. Keychain configuration tests run under the same lock as
/// every other keychain test (`runWithMockBackend`) and reset in a defer.
struct ConfigurationTests {

    /// Whether `stream` yields within `seconds`. A stream on the wrong store never yields,
    /// so waiting without a limit would hang the run instead of failing the test.
    private static func yields(_ stream: AsyncStream<Void>, within seconds: Double = 2) async -> Bool {
        await withTaskGroup(of: Bool.self) { group in
            group.addTask {
                var iterator = stream.makeAsyncIterator()
                return await iterator.next() != nil
            }
            group.addTask {
                try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                return false
            }
            let first = await group.next() ?? false
            group.cancelAll()
            return first
        }
    }

    /// Points the application level at a throwaway suite, so a scope regression writes
    /// there instead of into the test runner's `.standard`.
    private static func configureThrowawayApplicationStore() -> @Sendable () -> Void {
        let (app, cleanup) = makeUserDefaults(suiteName: "swiftstash.tests.config.throwaway.\(UUID().uuidString)")
        SwiftStash.configureUserDefaults(app)
        return cleanup
    }

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
    func `configureUserDefaults with an instance is honoured by every wrapper kind`() async {
        await #expect(processExitsWith: .success) {
            let suiteName = "swiftstash.tests.config.instance.\(UUID().uuidString)"
            defer { UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName) }
            let suite = UserDefaults(suiteName: suiteName)!

            SwiftStash.configureUserDefaults(suite)
            #expect(SwiftStash.userDefaults === suite)

            Stash<Int>(key: "instanceStash", defaultValue: 0).wrappedValue = 1
            #expect(suite.integer(forKey: "instanceStash") == 1)

            await MainActor.run {
                Stashed<Int>(key: "instanceStashed", defaultValue: 0).wrappedValue = 2
            }
            #expect(suite.integer(forKey: "instanceStashed") == 2)

            let updates = SwiftStash.updates(forKey: "instanceUpdates")
            suite.set(3, forKey: "instanceUpdates")
            #expect(await Self.yields(updates))
        }
    }

    @Test
    func `Two scopes with the same key do not collide`() async {
        await #expect(processExitsWith: .success) {
            let (first, cleanupFirst) = makeUserDefaults(suiteName: "swiftstash.tests.config.scopeA.\(UUID().uuidString)")
            let (second, cleanupSecond) = makeUserDefaults(suiteName: "swiftstash.tests.config.scopeB.\(UUID().uuidString)")
            defer {
                cleanupFirst()
                cleanupSecond()
            }

            let cleanupApp = Self.configureThrowawayApplicationStore()
            defer { cleanupApp() }
            SwiftStash.configureUserDefaults(first, for: .testScope)
            SwiftStash.configureUserDefaults(second, for: .otherTestScope)

            Stash<Int>(key: TestScopedKey.counter, defaultValue: 0).wrappedValue = 1
            Stash<Int>(key: OtherTestScopedKey.counter, defaultValue: 0).wrappedValue = 2

            #expect(first.integer(forKey: "counter") == 1)
            #expect(second.integer(forKey: "counter") == 2)
            #expect(SwiftStash.userDefaults(for: .testScope) === first)
            #expect(SwiftStash.userDefaults(for: .otherTestScope) === second)
        }
    }

    @Test
    func `An unconfigured scope falls back to the application-level store`() async {
        await #expect(processExitsWith: .success) {
            let (app, cleanup) = makeUserDefaults(suiteName: "swiftstash.tests.config.scopeFallback.\(UUID().uuidString)")
            defer { cleanup() }

            SwiftStash.configureUserDefaults(app)

            Stash<Int>(key: TestScopedKey.counter, defaultValue: 0).wrappedValue = 4

            #expect(app.integer(forKey: "counter") == 4)
            #expect(SwiftStash.userDefaults(for: .testScope) === app)
        }
    }

    @Test
    func `Scope store wins over the application-level store`() async {
        await #expect(processExitsWith: .success) {
            let (app, cleanupApp) = makeUserDefaults(suiteName: "swiftstash.tests.config.rungApp.\(UUID().uuidString)")
            let (scoped, cleanupScoped) = makeUserDefaults(suiteName: "swiftstash.tests.config.rungScope.\(UUID().uuidString)")
            defer {
                cleanupApp()
                cleanupScoped()
            }

            SwiftStash.configureUserDefaults(app)
            SwiftStash.configureUserDefaults(scoped, for: .testScope)

            Stash<Int>(key: TestScopedKey.counter, defaultValue: 0).wrappedValue = 5
            await MainActor.run {
                Stashed<Int>(key: TestScopedKey.counter, defaultValue: 0).wrappedValue = 6
            }
            // A plain key in the same process stays on the application level.
            Stash<Int>(key: "counter", defaultValue: 0).wrappedValue = 7

            #expect(scoped.integer(forKey: "counter") == 6)
            #expect(app.integer(forKey: "counter") == 7)
        }
    }

    @Test
    func `Explicit userDefaults wins over the scope store`() async {
        await #expect(processExitsWith: .success) {
            let (scoped, cleanupScoped) = makeUserDefaults(suiteName: "swiftstash.tests.config.rungScope.\(UUID().uuidString)")
            let (explicit, cleanupExplicit) = makeUserDefaults(suiteName: "swiftstash.tests.config.rungExplicit.\(UUID().uuidString)")
            defer {
                cleanupScoped()
                cleanupExplicit()
            }

            let cleanupApp = Self.configureThrowawayApplicationStore()
            defer { cleanupApp() }
            SwiftStash.configureUserDefaults(scoped, for: .testScope)

            Stash<Int>(key: TestScopedKey.counter, defaultValue: 0, userDefaults: explicit).wrappedValue = 8

            #expect(explicit.integer(forKey: "counter") == 8)
            #expect(scoped.object(forKey: "counter") == nil)
        }
    }

    @Test
    func `updates for a scoped key observes the scope store`() async {
        await #expect(processExitsWith: .success) {
            let (scoped, cleanup) = makeUserDefaults(suiteName: "swiftstash.tests.config.scopedUpdates.\(UUID().uuidString)")
            defer { cleanup() }

            let cleanupApp = Self.configureThrowawayApplicationStore()
            defer { cleanupApp() }
            SwiftStash.configureUserDefaults(scoped, for: .testScope)

            let updates = SwiftStash.updates(forKey: TestScopedKey.counter)
            scoped.set(9, forKey: "counter")
            #expect(await Self.yields(updates))
        }
    }

    #if canImport(AppKit)
    @Test
    func `Hosted Stashed without stashStore falls back to the configured store`() async {
        await #expect(processExitsWith: .success) {
            let (app, cleanup) = makeUserDefaults(suiteName: "swiftstash.tests.config.hostedFallback.\(UUID().uuidString)")
            defer { cleanup() }
            app.set(10, forKey: "hostedFallback")

            SwiftStash.configureUserDefaults(app)

            await MainActor.run {
                let probe = StashedProbe()
                let host = HostedView(StashedProbeView(key: "hostedFallback", probe: probe))
                #expect(probe.renderedValue == 10)

                probe.write(11)
                host.render()
            }
            #expect(app.integer(forKey: "hostedFallback") == 11)
        }
    }

    @Test
    func `Environment store wins over the scope store`() async {
        await #expect(processExitsWith: .success) {
            let (scoped, cleanupScoped) = makeUserDefaults(suiteName: "swiftstash.tests.config.rungScope.\(UUID().uuidString)")
            let (environment, cleanupEnvironment) = makeUserDefaults(suiteName: "swiftstash.tests.config.rungEnvironment.\(UUID().uuidString)")
            defer {
                cleanupScoped()
                cleanupEnvironment()
            }
            scoped.set(1, forKey: "counter")
            environment.set(2, forKey: "counter")

            let cleanupApp = Self.configureThrowawayApplicationStore()
            defer { cleanupApp() }
            SwiftStash.configureUserDefaults(scoped, for: .testScope)

            await MainActor.run {
                let probe = StashedProbe()
                _ = HostedView(StashedProbeView(scopedKey: .counter, probe: probe).stashStore(environment))
                #expect(probe.renderedValue == 2)
            }
        }
    }
    #endif

    @Test
    func `resetUserDefaults restores standard and removes every scope store`() async {
        await #expect(processExitsWith: .success) {
            let (app, cleanupApp) = makeUserDefaults(suiteName: "swiftstash.tests.config.reset.\(UUID().uuidString)")
            let (scoped, cleanupScoped) = makeUserDefaults(suiteName: "swiftstash.tests.config.resetScope.\(UUID().uuidString)")
            defer {
                cleanupApp()
                cleanupScoped()
            }

            SwiftStash.configureUserDefaults(app)
            SwiftStash.configureUserDefaults(scoped, for: .testScope)
            SwiftStash.configureUserDefaults(scoped, for: .otherTestScope)

            SwiftStash.resetUserDefaults(for: .otherTestScope)
            #expect(SwiftStash.userDefaults(for: .otherTestScope) === app)
            #expect(SwiftStash.userDefaults(for: .testScope) === scoped)

            SwiftStash.resetUserDefaults()
            #expect(SwiftStash.userDefaults === UserDefaults.standard)
            #expect(SwiftStash.userDefaults(for: .testScope) === UserDefaults.standard)
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
