//
//  StashErgonomicsTests.swift
//  SwiftStash
//
// Copyright (c) 2026 SwiftStash contributors
// SPDX-License-Identifier: MIT
//

import Foundation
import Testing
@testable import SwiftStash
import SwiftStashUI

// MARK: - Test Key Enum

private enum TestSettingsKey: String {
    case username
    case launchCount
    case lastLogin
    case profile
    case theme
    case priority
}

// MARK: - Static Context

/// Compiles only if `Stash` is `Sendable`: a non-Sendable `static let` is an error
/// under Swift 6 strict concurrency.
private enum StaticStashContainer {
    static let suiteName = "swiftstash.tests.staticStash"
    static let counter = Stash<Int>(
        key: "static.counter",
        defaultValue: 0,
        userDefaults: UserDefaults(suiteName: suiteName)!
    )
}

/// Compiles only if the `@Stash` attribute is usable on a `static var`. Swift 6
/// rejects that spelling in a nonisolated type (the synthesized backing storage is
/// nonisolated global mutable state, regardless of `Sendable`), so the container
/// must be actor-isolated; nonisolated types use the `static let` wrapper-instance
/// form above instead.
@MainActor
private enum StaticWrapperContainer {
    static let suiteName = "swiftstash.tests.staticWrapperStash"
    @Stash(key: "staticWrapper.logLevel", defaultValue: "normal", userDefaults: UserDefaults(suiteName: suiteName)!)
    static var logLevel: String
}

struct StashErgonomicsTests {

    // MARK: - Nonmutating Set

    @Test
    func `Stash can be written through a let container instance`() {
        let (userDefaults, cleanup) = makeUserDefaults(suiteName: UUID().uuidString)
        defer { cleanup() }

        struct Container {
            @Stash var count: Int

            init(userDefaults: UserDefaults) {
                _count = Stash(key: "letContext.count", defaultValue: 0, userDefaults: userDefaults)
            }
        }

        let container = Container(userDefaults: userDefaults)

        container.count = 5

        #expect(container.count == 5)
    }

    @Test
    func `Stash declared as let can be written directly`() {
        let (userDefaults, cleanup) = makeUserDefaults(suiteName: UUID().uuidString)
        defer { cleanup() }

        let stash = Stash<Int>(key: "letContext.direct", defaultValue: 0, userDefaults: userDefaults)

        stash.wrappedValue = 7

        #expect(stash.wrappedValue == 7)
    }

    @Test
    func `SecureStash declared as let can be written directly`() {
        runWithMockBackend { _ in
            let stash = SecureStash<String?>(key: "letContext.secure", service: "swiftstash.tests.ergonomics")

            stash.wrappedValue = "secret"

            #expect(stash.wrappedValue == "secret")
        }
    }

    // MARK: - Sendable / Static Context

    @Test
    func `Stash works as a static let and persists values`() {
        defer {
            UserDefaults(suiteName: StaticStashContainer.suiteName)?
                .removePersistentDomain(forName: StaticStashContainer.suiteName)
        }

        StaticStashContainer.counter.wrappedValue = 3

        #expect(StaticStashContainer.counter.wrappedValue == 3)
    }

    @Test @MainActor
    func `Stash attribute works on a static var in an actor-isolated type`() {
        defer {
            UserDefaults(suiteName: StaticWrapperContainer.suiteName)?
                .removePersistentDomain(forName: StaticWrapperContainer.suiteName)
        }

        StaticWrapperContainer.logLevel = "verbose"

        #expect(StaticWrapperContainer.logLevel == "verbose")
    }

    @Test
    func `Stash can cross a concurrency boundary`() async {
        let suiteName = UUID().uuidString
        let (userDefaults, cleanup) = makeUserDefaults(suiteName: suiteName)
        defer { cleanup() }

        let stash = Stash<Int>(key: "sendable.crossing", defaultValue: 0, userDefaults: userDefaults)

        await Task.detached {
            stash.wrappedValue = 11
        }.value

        #expect(stash.wrappedValue == 11)
    }

    // MARK: - String-Backed Key Enums

    @Test
    func `Primitive Stash accepts a key enum and stores under its raw value`() {
        let (userDefaults, cleanup) = makeUserDefaults(suiteName: UUID().uuidString)
        defer { cleanup() }

        let stash = Stash<String>(key: TestSettingsKey.username, defaultValue: "", userDefaults: userDefaults)

        stash.wrappedValue = "tomek"

        #expect(stash.wrappedValue == "tomek")
        #expect(userDefaults.string(forKey: "username") == "tomek")
    }

    @Test
    func `Optional primitive Stash accepts a key enum`() {
        let (userDefaults, cleanup) = makeUserDefaults(suiteName: UUID().uuidString)
        defer { cleanup() }

        let stash = Stash<Date?>(key: TestSettingsKey.lastLogin, userDefaults: userDefaults)

        #expect(stash.wrappedValue == nil)

        let now = Date()
        stash.wrappedValue = now

        #expect(stash.wrappedValue == now)
        #expect(userDefaults.object(forKey: "lastLogin") != nil)
    }

    @Test
    func `Codable Stash accepts a key enum`() {
        let (userDefaults, cleanup) = makeUserDefaults(suiteName: UUID().uuidString)
        defer { cleanup() }

        let defaultProfile = UserProfile(name: "Default", age: 0, email: "default@example.com")
        let stash = Stash<UserProfile>(codable: TestSettingsKey.profile, defaultValue: defaultProfile, userDefaults: userDefaults)

        #expect(stash.wrappedValue == defaultProfile)

        let profile = UserProfile(name: "Tomek", age: 40, email: "tomek@example.com")
        stash.wrappedValue = profile

        #expect(stash.wrappedValue == profile)
        #expect(userDefaults.data(forKey: "profile") != nil)
    }

    @Test
    func `Optional codable Stash accepts a key enum`() {
        let (userDefaults, cleanup) = makeUserDefaults(suiteName: UUID().uuidString)
        defer { cleanup() }

        let stash = Stash<UserProfile?>(codable: TestSettingsKey.profile, userDefaults: userDefaults)

        #expect(stash.wrappedValue == nil)

        let profile = UserProfile(name: "Tomek", age: 40, email: "tomek@example.com")
        stash.wrappedValue = profile

        #expect(stash.wrappedValue == profile)
    }

    @Test
    func `RawRepresentable Stash accepts a key enum and stores the plain raw value`() {
        let (userDefaults, cleanup) = makeUserDefaults(suiteName: UUID().uuidString)
        defer { cleanup() }

        let stash = Stash<Theme>(key: TestSettingsKey.theme, defaultValue: .system, userDefaults: userDefaults)

        stash.wrappedValue = .dark

        #expect(stash.wrappedValue == .dark)
        #expect(userDefaults.string(forKey: "theme") == "dark")
    }

    @Test
    func `Optional RawRepresentable Stash accepts a key enum`() {
        let (userDefaults, cleanup) = makeUserDefaults(suiteName: UUID().uuidString)
        defer { cleanup() }

        let stash = Stash<Priority?>(key: TestSettingsKey.priority, userDefaults: userDefaults)

        #expect(stash.wrappedValue == nil)

        stash.wrappedValue = .high

        #expect(stash.wrappedValue == .high)
        #expect(userDefaults.integer(forKey: "priority") == Priority.high.rawValue)
    }

    @Test
    func `AppStorage-style Stash declaration works with a key enum`() {
        defer {
            UserDefaults.standard.removeObject(forKey: TestSettingsKey.launchCount.rawValue)
            UserDefaults.standard.removeObject(forKey: TestSettingsKey.username.rawValue)
        }

        struct AppStorageStyleStorage {
            @Stash(TestSettingsKey.launchCount) var count: Int = 9
            @Stash(TestSettingsKey.username) var username: String?
        }

        let sut = AppStorageStyleStorage()

        #expect(sut.count == 9)
        #expect(sut.username == nil)

        sut.count = 42
        sut.username = "tomek"

        #expect(sut.count == 42)
        #expect(sut.username == "tomek")
    }

    @Test
    func `SecureStash accepts a key enum`() {
        runWithMockBackend { _ in
            let stash = SecureStash<String?>(key: TestSettingsKey.username, service: "swiftstash.tests.ergonomics")

            stash.wrappedValue = "secret"

            #expect(stash.wrappedValue == "secret")
        }
    }

    @Test @MainActor
    func `Stashed accepts a key enum and stores under its raw value`() {
        let (userDefaults, cleanup) = makeUserDefaults(suiteName: UUID().uuidString)
        defer { cleanup() }

        let stashed = Stashed<Theme>(key: TestSettingsKey.theme, defaultValue: .system, store: userDefaults)

        stashed.wrappedValue = .light

        #expect(stashed.wrappedValue == .light)
        #expect(userDefaults.string(forKey: "theme") == "light")
    }
}

// Keychain-backed tests use the shared runWithMockBackend from TestHelpers —
// the backend swap is process-global, so every suite must serialise on the same lock.
