//
//  StashedEnvironmentTests.swift
//  SwiftStash
//
// Copyright (c) 2026 SwiftStash contributors
// SPDX-License-Identifier: MIT
//

#if canImport(AppKit)
import Foundation
import Testing
import SwiftUI
import SwiftStash
import SwiftStashUI

/// Tests for `@Stashed` resolving its store from the SwiftUI environment (`.stashStore`).
///
/// Tests cover:
/// - a hosted view reading and writing the environment's store, never `.standard`
/// - switching the observer when the environment's store changes
/// - an explicit `store:` winning over the environment
/// - scoped environment stores for keys whose type declares a `StashScope`
/// - re-rendering for writes through the binding and through the store directly
///
/// Every view is hosted in an `NSHostingView`, so `DynamicProperty.update()` runs as in an
/// app. The fallback to the configured store mutates global state and lives in
/// `ConfigurationTests`, inside exit tests.
@MainActor
struct StashedEnvironmentTests {

    private struct EnvironmentRoot: View {
        let key: String
        let environmentStore: UserDefaults
        var explicitStore: UserDefaults?
        let probe: StashedProbe

        var body: some View {
            StashedProbeView(key: key, store: explicitStore, probe: probe)
                .stashStore(environmentStore)
        }
    }

    /// A key no other test uses. Should a regression send a write to `.standard`, the
    /// returned cleanup removes it again, so a failing run leaves no trace there.
    private static func uniqueKey() -> (key: String, cleanup: () -> Void) {
        let key = "environmentTests_\(UUID().uuidString.replacingOccurrences(of: "-", with: ""))"
        return (key, { UserDefaults.standard.removeObject(forKey: key) })
    }

    @Test
    func `Hosted view reads and writes the environment store and leaves standard untouched`() {
        let (suite, cleanup) = makeUserDefaults(suiteName: "environment.readwrite.\(UUID().uuidString)")
        defer { cleanup() }
        let (key, removeStrayKey) = Self.uniqueKey()
        defer { removeStrayKey() }
        suite.set(41, forKey: key)

        let probe = StashedProbe()
        let host = HostedView(EnvironmentRoot(key: key, environmentStore: suite, probe: probe))

        #expect(probe.renderedValue == 41)

        probe.write(42)
        host.render()

        #expect(suite.integer(forKey: key) == 42)
        #expect(probe.renderedValue == 42)
        #expect(UserDefaults.standard.object(forKey: key) == nil)
    }

    @Test
    func `Changing the environment store switches the observer to the new store`() async {
        let (first, cleanupFirst) = makeUserDefaults(suiteName: "environment.switch.first.\(UUID().uuidString)")
        let (second, cleanupSecond) = makeUserDefaults(suiteName: "environment.switch.second.\(UUID().uuidString)")
        defer {
            cleanupFirst()
            cleanupSecond()
        }
        let (key, removeStrayKey) = Self.uniqueKey()
        defer { removeStrayKey() }
        first.set(1, forKey: key)
        second.set(2, forKey: key)

        let probe = StashedProbe()
        let host = HostedView(EnvironmentRoot(key: key, environmentStore: first, probe: probe))
        #expect(probe.renderedValue == 1)

        host.update(EnvironmentRoot(key: key, environmentStore: second, probe: probe))
        #expect(probe.renderedValue == 2)

        probe.write(20)
        host.render()

        #expect(second.integer(forKey: key) == 20)
        #expect(first.integer(forKey: key) == 1)
        #expect(probe.renderedValue == 20)

        // Writes to the store the view left no longer reach it.
        let rendersBefore = probe.renderCount
        first.set(10, forKey: key)
        await host.settle()

        #expect(probe.renderCount == rendersBefore)
        #expect(probe.renderedValue == 20)
    }

    @Test
    func `Explicit store wins over the environment store`() {
        let (environment, cleanupEnvironment) = makeUserDefaults(suiteName: "environment.explicit.env.\(UUID().uuidString)")
        let (explicit, cleanupExplicit) = makeUserDefaults(suiteName: "environment.explicit.store.\(UUID().uuidString)")
        defer {
            cleanupEnvironment()
            cleanupExplicit()
        }
        let (key, removeStrayKey) = Self.uniqueKey()
        defer { removeStrayKey() }
        environment.set(1, forKey: key)
        explicit.set(2, forKey: key)

        let probe = StashedProbe()
        let host = HostedView(
            EnvironmentRoot(key: key, environmentStore: environment, explicitStore: explicit, probe: probe)
        )

        #expect(probe.renderedValue == 2)

        probe.write(3)
        host.render()

        #expect(explicit.integer(forKey: key) == 3)
        #expect(environment.integer(forKey: key) == 1)
    }

    @Test
    func `External write to the environment store re-renders the hosted view`() async {
        let (suite, cleanup) = makeUserDefaults(suiteName: "environment.external.\(UUID().uuidString)")
        defer { cleanup() }
        let (key, removeStrayKey) = Self.uniqueKey()
        defer { removeStrayKey() }

        let probe = StashedProbe()
        let host = HostedView(EnvironmentRoot(key: key, environmentStore: suite, probe: probe))
        #expect(probe.renderedValue == 0)

        suite.set(7, forKey: key)

        #expect(await host.settle { probe.renderedValue == 7 })
    }

    @Test
    func `Scoped environment store wins over the unscoped one for a scoped key`() {
        let (all, cleanupAll) = makeUserDefaults(suiteName: "environment.scoped.all.\(UUID().uuidString)")
        let (scoped, cleanupScoped) = makeUserDefaults(suiteName: "environment.scoped.scope.\(UUID().uuidString)")
        defer {
            cleanupAll()
            cleanupScoped()
        }
        let key = TestScopedKey.counter.rawValue
        all.set(1, forKey: key)
        scoped.set(2, forKey: key)

        let scopedProbe = StashedProbe()
        let unscopedProbe = StashedProbe()
        _ = HostedView(
            VStack {
                StashedProbeView(scopedKey: .counter, probe: scopedProbe)
                StashedProbeView(key: key, probe: unscopedProbe)
            }
            .stashStore(scoped, for: .testScope)
            .stashStore(all)
        )

        #expect(scopedProbe.renderedValue == 2)
        #expect(unscopedProbe.renderedValue == 1)
    }

    @Test
    func `Unscoped environment store covers a scoped key without a scoped entry`() {
        let (all, cleanup) = makeUserDefaults(suiteName: "environment.scoped.cover.\(UUID().uuidString)")
        defer { cleanup() }
        all.set(5, forKey: TestScopedKey.counter.rawValue)

        let probe = StashedProbe()
        let host = HostedView(StashedProbeView(scopedKey: .counter, probe: probe).stashStore(all))

        #expect(probe.renderedValue == 5)

        probe.write(6)
        host.render()

        #expect(all.integer(forKey: TestScopedKey.counter.rawValue) == 6)
    }

    @Test
    func `Nearest unscoped modifier replaces scoped stores set further up`() {
        let (outerScoped, cleanupOuter) = makeUserDefaults(suiteName: "environment.nearest.outer.\(UUID().uuidString)")
        let (inner, cleanupInner) = makeUserDefaults(suiteName: "environment.nearest.inner.\(UUID().uuidString)")
        defer {
            cleanupOuter()
            cleanupInner()
        }
        outerScoped.set(1, forKey: TestScopedKey.counter.rawValue)
        inner.set(2, forKey: TestScopedKey.counter.rawValue)

        let probe = StashedProbe()
        _ = HostedView(
            StashedProbeView(scopedKey: .counter, probe: probe)
                .stashStore(inner)
                .stashStore(outerScoped, for: .testScope)
        )

        #expect(probe.renderedValue == 2)
    }
}
#endif
