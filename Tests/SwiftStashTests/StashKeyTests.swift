//
//  StashKeyTests.swift
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

// MARK: - Keys

private enum StashKeyTestName: String {
    case keyTypeCount
}

extension StashKey<Int> {
    fileprivate static var keyCount: Self { .init("keyCount", default: 7) }
    fileprivate static var keyTypeCount: Self { .init(StashKeyTestName.keyTypeCount, default: 3) }
    fileprivate static var scopedCount: Self { .init(TestScopedKey.counter, default: 11) }
}

extension StashKey<Int?> {
    fileprivate static var keyOptionalCount: Self { .init("keyOptionalCount") }
}

extension StashKey<Priority> {
    fileprivate static var keyPriority: Self { .init("keyPriority", default: .medium) }
}

extension StashKey<Priority?> {
    fileprivate static var keyOptionalPriority: Self { .init("keyOptionalPriority") }
    fileprivate static var keyOptionalPriorityWithDefault: Self { .init("keyOptionalPriorityWithDefault", default: .high) }
}

extension StashKey<UserProfile> {
    fileprivate static var keyProfile: Self {
        .init("keyProfile", default: UserProfile(name: "Default", age: 0, email: "default@example.com"))
    }
}

extension StashKey<UserProfile?> {
    fileprivate static var keyOptionalProfile: Self { .init("keyOptionalProfile") }
}

extension StashKey<Date> {
    fileprivate static var keyCheckpoint: Self { .init("keyCheckpoint", default: Date(timeIntervalSince1970: 0)) }
}

/// Tests for `StashKey`, a key that carries its value type and default.
///
/// Tests cover:
/// - every wrapper variant (primitive, optional, raw-representable, optional raw-representable,
///   Codable, optional Codable) for `@Stash` and `@Stashed`
/// - one default shared by a model's `@Stash` and a view's `@Stashed`
/// - keys built from a string-backed key type, and their `StashScope`
/// - `SwiftStash.updates(forKey:)` with a `StashKey`
///
/// Scope resolution through global configuration runs inside exit tests.
@MainActor
struct StashKeyTests {

    // MARK: - Stash

    @Test
    func `Primitive Stash reads the key's default and stores under its name`() {
        let (userDefaults, cleanup) = makeUserDefaults(suiteName: "stashKey.primitive.\(UUID().uuidString)")
        defer { cleanup() }

        let stash = Stash<Int>(.keyCount, userDefaults: userDefaults)
        #expect(stash.wrappedValue == 7)
        #expect(stash.projectedValue.exists == false)

        stash.wrappedValue = 8

        #expect(userDefaults.integer(forKey: "keyCount") == 8)
        #expect(stash.wrappedValue == 8)
    }

    @Test
    func `Key built from a key type stores under its raw value`() {
        let (userDefaults, cleanup) = makeUserDefaults(suiteName: "stashKey.keyType.\(UUID().uuidString)")
        defer { cleanup() }

        let stash = Stash<Int>(.keyTypeCount, userDefaults: userDefaults)
        #expect(stash.wrappedValue == 3)

        stash.wrappedValue = 4

        #expect(userDefaults.integer(forKey: StashKeyTestName.keyTypeCount.rawValue) == 4)
        #expect(StashKey<Int>.keyTypeCount.name == "keyTypeCount")
    }

    @Test
    func `Optional primitive key defaults to nil and nil removes the value`() {
        let (userDefaults, cleanup) = makeUserDefaults(suiteName: "stashKey.optional.\(UUID().uuidString)")
        defer { cleanup() }

        let stash = Stash<Int?>(.keyOptionalCount, userDefaults: userDefaults)
        #expect(stash.wrappedValue == nil)

        stash.wrappedValue = 5
        #expect(userDefaults.integer(forKey: "keyOptionalCount") == 5)

        stash.wrappedValue = nil
        #expect(userDefaults.object(forKey: "keyOptionalCount") == nil)
    }

    @Test
    func `RawRepresentable key stores the plain raw value`() {
        let (userDefaults, cleanup) = makeUserDefaults(suiteName: "stashKey.raw.\(UUID().uuidString)")
        defer { cleanup() }

        let stash = Stash<Priority>(.keyPriority, userDefaults: userDefaults)
        #expect(stash.wrappedValue == .medium)

        stash.wrappedValue = .high

        #expect(userDefaults.integer(forKey: "keyPriority") == Priority.high.rawValue)
    }

    @Test
    func `Optional RawRepresentable key defaults to nil`() {
        let (userDefaults, cleanup) = makeUserDefaults(suiteName: "stashKey.optionalRaw.\(UUID().uuidString)")
        defer { cleanup() }

        let stash = Stash<Priority?>(.keyOptionalPriority, userDefaults: userDefaults)
        #expect(stash.wrappedValue == nil)

        stash.wrappedValue = .low
        #expect(userDefaults.integer(forKey: "keyOptionalPriority") == Priority.low.rawValue)
    }

    @Test
    func `Optional RawRepresentable key with a default returns it while nothing is stored`() {
        let (userDefaults, cleanup) = makeUserDefaults(suiteName: "stashKey.optionalRawDefault.\(UUID().uuidString)")
        defer { cleanup() }

        let stash = Stash<Priority?>(.keyOptionalPriorityWithDefault, userDefaults: userDefaults)
        #expect(stash.wrappedValue == .high)

        stash.wrappedValue = .low
        #expect(stash.wrappedValue == .low)

        stash.wrappedValue = nil
        #expect(userDefaults.object(forKey: "keyOptionalPriorityWithDefault") == nil)
        #expect(stash.wrappedValue == .high)

        userDefaults.set(999, forKey: "keyOptionalPriorityWithDefault")
        #expect(stash.wrappedValue == .high)
    }

    @Test
    func `Codable key reads the default and stores JSON`() throws {
        let (userDefaults, cleanup) = makeUserDefaults(suiteName: "stashKey.codable.\(UUID().uuidString)")
        defer { cleanup() }

        let stash = Stash<UserProfile>(codable: .keyProfile, userDefaults: userDefaults)
        #expect(stash.wrappedValue.name == "Default")

        let profile = UserProfile(name: "Tomek", age: 40, email: "tomek@example.com")
        stash.wrappedValue = profile

        let data = try #require(userDefaults.data(forKey: "keyProfile"))
        #expect(try JSONDecoder().decode(UserProfile.self, from: data) == profile)
    }

    @Test
    func `Optional Codable key defaults to nil and nil removes the value`() {
        let (userDefaults, cleanup) = makeUserDefaults(suiteName: "stashKey.optionalCodable.\(UUID().uuidString)")
        defer { cleanup() }

        let stash = Stash<UserProfile?>(codable: .keyOptionalProfile, userDefaults: userDefaults)
        #expect(stash.wrappedValue == nil)

        stash.wrappedValue = UserProfile(name: "A", age: 1, email: "a@example.com")
        #expect(userDefaults.data(forKey: "keyOptionalProfile") != nil)

        stash.wrappedValue = nil
        #expect(userDefaults.object(forKey: "keyOptionalProfile") == nil)
    }

    @Test
    func `Codable key passes custom coders through`() throws {
        let (userDefaults, cleanup) = makeUserDefaults(suiteName: "stashKey.coders.\(UUID().uuidString)")
        defer { cleanup() }

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let stash = Stash<Date>(codable: .keyCheckpoint, userDefaults: userDefaults, encoder: encoder, decoder: decoder)
        stash.wrappedValue = Date(timeIntervalSince1970: 86_400)

        let data = try #require(userDefaults.data(forKey: "keyCheckpoint"))
        #expect(String(decoding: data, as: UTF8.self) == "\"1970-01-02T00:00:00Z\"")
        #expect(stash.wrappedValue == Date(timeIntervalSince1970: 86_400))
    }

    // MARK: - Stashed

    @Test
    func `Model Stash and view Stashed share the key's default`() async {
        let (userDefaults, cleanup) = makeUserDefaults(suiteName: "stashKey.shared.\(UUID().uuidString)")
        defer { cleanup() }

        let model = Stash<Int>(.keyCount, userDefaults: userDefaults)
        let view = Stashed<Int>(.keyCount, store: userDefaults)

        #expect(model.wrappedValue == 7)
        #expect(view.wrappedValue == 7)

        model.wrappedValue = 9
        // The view's shared observer learns of the model's write through KVO, debounced.
        try? await Task.sleep(nanoseconds: 100_000_000)
        #expect(view.wrappedValue == 9)
    }

    @Test
    func `Stashed accepts every key variant`() async {
        let (userDefaults, cleanup) = makeUserDefaults(suiteName: "stashKey.stashed.\(UUID().uuidString)")
        defer { cleanup() }

        let optional = Stashed<Int?>(.keyOptionalCount, store: userDefaults)
        let raw = Stashed<Priority>(.keyPriority, store: userDefaults)
        let optionalRaw = Stashed<Priority?>(.keyOptionalPriorityWithDefault, store: userDefaults)
        let codable = Stashed<UserProfile>(codable: .keyProfile, store: userDefaults)
        let optionalCodable = Stashed<UserProfile?>(codable: .keyOptionalProfile, store: userDefaults)

        #expect(optional.wrappedValue == nil)
        #expect(raw.wrappedValue == .medium)
        #expect(optionalRaw.wrappedValue == .high)
        #expect(codable.wrappedValue.name == "Default")
        #expect(optionalCodable.wrappedValue == nil)

        raw.wrappedValue = .low
        optionalRaw.wrappedValue = nil

        #expect(userDefaults.integer(forKey: "keyPriority") == Priority.low.rawValue)
        #expect(userDefaults.object(forKey: "keyOptionalPriorityWithDefault") == nil)
        // Assigning nil removes the key; the observer re-reads the key's default once the
        // debounced change notification arrives.
        try? await Task.sleep(nanoseconds: 100_000_000)
        #expect(optionalRaw.wrappedValue == .high)
    }

    #if canImport(AppKit)
    @Test
    func `Hosted Stashed with a scoped key honours the scoped environment store`() {
        let (all, cleanupAll) = makeUserDefaults(suiteName: "stashKey.env.all.\(UUID().uuidString)")
        let (scoped, cleanupScoped) = makeUserDefaults(suiteName: "stashKey.env.scope.\(UUID().uuidString)")
        defer {
            cleanupAll()
            cleanupScoped()
        }
        scoped.set(12, forKey: TestScopedKey.counter.rawValue)

        struct ScopedKeyView: View {
            @Stashed(.scopedCount) var count: Int
            let probe: StashedProbe

            var body: some View {
                probe.record(count, binding: $count)
                return Text("\(count)")
            }
        }

        let probe = StashedProbe()
        _ = HostedView(
            ScopedKeyView(probe: probe)
                .stashStore(scoped, for: .testScope)
                .stashStore(all)
        )

        #expect(probe.renderedValue == 12)
    }
    #endif

    // MARK: - Observation

    @Test
    func `updates accepts a StashKey`() async {
        let (userDefaults, cleanup) = makeUserDefaults(suiteName: "stashKey.updates.\(UUID().uuidString)")
        defer { cleanup() }

        let updates = SwiftStash.updates(forKey: StashKey<Int>.keyCount, in: userDefaults)
        userDefaults.set(1, forKey: "keyCount")

        var iterator = updates.makeAsyncIterator()
        #expect(await iterator.next() != nil)
    }

    // MARK: - Scope and configuration

    @Test
    func `Store-less declarations with a scoped key resolve the scope's store`() async {
        await #expect(processExitsWith: .success) {
            let (app, cleanupApp) = makeUserDefaults(suiteName: "swiftstash.tests.stashKey.app.\(UUID().uuidString)")
            let (scoped, cleanupScoped) = makeUserDefaults(suiteName: "swiftstash.tests.stashKey.scope.\(UUID().uuidString)")
            defer {
                cleanupApp()
                cleanupScoped()
            }

            SwiftStash.configureUserDefaults(app)
            SwiftStash.configureUserDefaults(scoped, for: .testScope)

            struct Model {
                @Stash(.scopedCount) var count: Int
                @Stash(.keyCount) var plainCount: Int
            }

            let model = Model()
            #expect(model.count == 11)
            model.count = 13
            model.plainCount = 14

            #expect(scoped.integer(forKey: "counter") == 13)
            #expect(app.integer(forKey: "keyCount") == 14)

            await MainActor.run {
                #expect(Stashed<Int>(.scopedCount).wrappedValue == 13)
            }
        }
    }

    @Test
    func `Explicit store wins over the scope of a StashKey`() async {
        await #expect(processExitsWith: .success) {
            let (app, cleanupApp) = makeUserDefaults(suiteName: "swiftstash.tests.stashKey.app.\(UUID().uuidString)")
            let (scoped, cleanupScoped) = makeUserDefaults(suiteName: "swiftstash.tests.stashKey.scope.\(UUID().uuidString)")
            let (explicit, cleanupExplicit) = makeUserDefaults(suiteName: "swiftstash.tests.stashKey.explicit.\(UUID().uuidString)")
            defer {
                cleanupApp()
                cleanupScoped()
                cleanupExplicit()
            }

            SwiftStash.configureUserDefaults(app)
            SwiftStash.configureUserDefaults(scoped, for: .testScope)

            Stash<Int>(.scopedCount, userDefaults: explicit).wrappedValue = 15

            #expect(explicit.integer(forKey: "counter") == 15)
            #expect(scoped.object(forKey: "counter") == nil)
        }
    }
}
