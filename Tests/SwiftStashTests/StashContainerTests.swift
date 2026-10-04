//
//  StashContainerTests.swift
//  SwiftStash
//
// Copyright (c) 2026 SwiftStash contributors
// SPDX-License-Identifier: MIT
//

import Foundation
import Testing
@testable import SwiftStash

// MARK: - Keys and containers

extension StashKey<Int> {
    fileprivate static var containerCount: Self { .init("containerTests_count", default: 1) }
    fileprivate static var containerScopedCount: Self { .init(TestScopedKey.counter, default: 2) }
}

private enum ContainerKey: String {
    case typedKeyName = "containerTests_typedKeyName"
}

/// Every key the container tests write. A regression that sent a container's write to the
/// fallback store would land in the runner's `.standard`; each test removes these keys from
/// it again, so a failing run leaves no trace there.
private let containerTestKeys = [
    "containerTests_count", "containerTests_name", "containerTests_lastLogin", "containerTests_priority",
    "containerTests_optionalPriority", "containerTests_profile", "containerTests_typedKeyName",
]

private func removeStrayStandardKeys() {
    containerTestKeys.forEach { UserDefaults.standard.removeObject(forKey: $0) }
}

/// A container exercising every wrapper variant.
private final class SettingsContainer: StashContainer {
    let stashStore: StashStore

    @Stash(.containerCount) var count: Int
    @Stash("containerTests_name") var name: String = "default"
    @Stash("containerTests_lastLogin") var lastLogin: Date?
    @Stash("containerTests_priority") var priority: Priority = .medium
    @Stash("containerTests_optionalPriority") var optionalPriority: Priority?
    @Stash(codable: "containerTests_profile") var profile: UserProfile?
    @Stash(ContainerKey.typedKeyName) var typedKeyName: String = ""

    init(_ userDefaults: UserDefaults) {
        stashStore = StashStore(userDefaults)
    }
}

@MainActor
private final class MainActorContainer: StashContainer {
    let stashStore: StashStore

    @Stash(.containerCount) var count: Int

    init(_ userDefaults: UserDefaults) {
        stashStore = StashStore(userDefaults)
    }
}

/// A container with one property pinned to an explicit store.
private final class ExplicitStoreContainer: StashContainer {
    let stashStore: StashStore
    @Stash var pinned: Int

    init(container: UserDefaults, pinned: UserDefaults) {
        stashStore = StashStore(container)
        _pinned = Stash(.containerCount, userDefaults: pinned)
    }
}

/// A container whose store can be replaced.
private final class SwitchingContainer: StashContainer {
    var stashStore: StashStore
    @Stash(.containerCount) var count: Int

    init(_ userDefaults: UserDefaults) {
        stashStore = StashStore(userDefaults)
    }
}

/// An ordinary class: `@Stash` keeps the store it resolved at initialisation.
private final class PlainClass {
    @Stash var count: Int

    init(_ userDefaults: UserDefaults) {
        _count = Stash(.containerCount, userDefaults: userDefaults)
    }
}

/// An actor keeps compiling and working with `@Stash` (it is not a container).
private actor PlainActor {
    @Stash var count: Int

    init(suiteName: String) {
        _count = Stash(.containerCount, userDefaults: UserDefaults(suiteName: suiteName)!)
    }

    func increment() -> Int {
        count += 1
        return count
    }
}

/// Tests for `StashContainer`: a class that holds the store for its `@Stash` properties.
///
/// Tests cover:
/// - every wrapper variant reading and writing the container's store
/// - the projected value (`exists`, `remove()`, `updates`) on the container's store
/// - main-actor containers, independent instances, and a replaced store
/// - an explicit `userDefaults:` winning over the container
/// - the container winning over scopes and the application level (exit test)
/// - ordinary classes and actors keeping their behaviour
struct StashContainerTests {

    @Test
    func `Every variant reads and writes the container store`() throws {
        defer { removeStrayStandardKeys() }
        let (userDefaults, cleanup) = makeUserDefaults(suiteName: "container.variants.\(UUID().uuidString)")
        defer { cleanup() }

        let settings = SettingsContainer(userDefaults)
        #expect(settings.count == 1)
        #expect(settings.name == "default")
        #expect(settings.priority == .medium)

        let profile = UserProfile(name: "Tomek", age: 40, email: "tomek@example.com")
        settings.count = 3
        settings.name = "tomek"
        settings.lastLogin = Date(timeIntervalSince1970: 100)
        settings.priority = .high
        settings.optionalPriority = .low
        settings.profile = profile
        settings.typedKeyName = "typed"

        #expect(userDefaults.integer(forKey: "containerTests_count") == 3)
        #expect(userDefaults.string(forKey: "containerTests_name") == "tomek")
        #expect(userDefaults.object(forKey: "containerTests_lastLogin") as? Date == Date(timeIntervalSince1970: 100))
        #expect(userDefaults.integer(forKey: "containerTests_priority") == Priority.high.rawValue)
        #expect(userDefaults.integer(forKey: "containerTests_optionalPriority") == Priority.low.rawValue)
        let data = try #require(userDefaults.data(forKey: "containerTests_profile"))
        #expect(try JSONDecoder().decode(UserProfile.self, from: data) == profile)
        #expect(userDefaults.string(forKey: "containerTests_typedKeyName") == "typed")

        #expect(settings.count == 3)
        #expect(settings.profile == profile)
    }

    @Test
    func `Projected value works on the container store`() async {
        defer { removeStrayStandardKeys() }
        let (userDefaults, cleanup) = makeUserDefaults(suiteName: "container.projected.\(UUID().uuidString)")
        defer { cleanup() }

        let settings = SettingsContainer(userDefaults)
        #expect(settings.$count.exists == false)

        userDefaults.set(5, forKey: "containerTests_count")
        #expect(settings.$count.exists)

        var updates = settings.$count.updates.makeAsyncIterator()
        #expect(await updates.next() == 5)

        settings.$count.remove()
        #expect(userDefaults.object(forKey: "containerTests_count") == nil)
        #expect(settings.count == 1)
    }

    @Test @MainActor
    func `Main-actor container uses its store`() {
        defer { removeStrayStandardKeys() }
        let (userDefaults, cleanup) = makeUserDefaults(suiteName: "container.mainActor.\(UUID().uuidString)")
        defer { cleanup() }

        let settings = MainActorContainer(userDefaults)
        settings.count = 9

        #expect(userDefaults.integer(forKey: "containerTests_count") == 9)
        #expect(settings.count == 9)
    }

    @Test
    func `Two instances with different stores do not collide`() {
        defer { removeStrayStandardKeys() }
        let (first, cleanupFirst) = makeUserDefaults(suiteName: "container.first.\(UUID().uuidString)")
        let (second, cleanupSecond) = makeUserDefaults(suiteName: "container.second.\(UUID().uuidString)")
        defer {
            cleanupFirst()
            cleanupSecond()
        }

        let a = SettingsContainer(first)
        let b = SettingsContainer(second)
        a.count = 10
        b.count = 20

        #expect(first.integer(forKey: "containerTests_count") == 10)
        #expect(second.integer(forKey: "containerTests_count") == 20)
        #expect(a.count == 10)
        #expect(b.count == 20)
    }

    @Test
    func `Replacing the container store moves the properties`() {
        defer { removeStrayStandardKeys() }
        let (first, cleanupFirst) = makeUserDefaults(suiteName: "container.switch.first.\(UUID().uuidString)")
        let (second, cleanupSecond) = makeUserDefaults(suiteName: "container.switch.second.\(UUID().uuidString)")
        defer {
            cleanupFirst()
            cleanupSecond()
        }
        first.set(1_000, forKey: "containerTests_count")

        let settings = SwitchingContainer(first)
        #expect(settings.count == 1_000)

        settings.stashStore = StashStore(second)
        settings.count = 2_000

        #expect(second.integer(forKey: "containerTests_count") == 2_000)
        #expect(first.integer(forKey: "containerTests_count") == 1_000)
    }

    @Test
    func `Explicit userDefaults wins over the container store`() {
        let (container, cleanupContainer) = makeUserDefaults(suiteName: "container.explicit.c.\(UUID().uuidString)")
        let (pinned, cleanupPinned) = makeUserDefaults(suiteName: "container.explicit.p.\(UUID().uuidString)")
        defer {
            cleanupContainer()
            cleanupPinned()
        }

        let settings = ExplicitStoreContainer(container: container, pinned: pinned)
        settings.pinned = 4
        #expect(settings.$pinned.exists)

        #expect(pinned.integer(forKey: "containerTests_count") == 4)
        #expect(container.object(forKey: "containerTests_count") == nil)
    }

    @Test
    func `Ordinary classes and actors keep the store resolved at initialisation`() async {
        let suiteName = "container.plain.\(UUID().uuidString)"
        let (userDefaults, cleanup) = makeUserDefaults(suiteName: suiteName)
        defer { cleanup() }

        let plain = PlainClass(userDefaults)
        plain.count = 6
        #expect(userDefaults.integer(forKey: "containerTests_count") == 6)
        #expect(plain.$count.exists)

        let actor = PlainActor(suiteName: suiteName)
        #expect(await actor.increment() == 7)
        #expect(userDefaults.integer(forKey: "containerTests_count") == 7)
    }

    @Test
    func `Container store wins over the scope and the application level`() async {
        await #expect(processExitsWith: .success) {
            let (app, cleanupApp) = makeUserDefaults(suiteName: "swiftstash.tests.container.app.\(UUID().uuidString)")
            let (scoped, cleanupScoped) = makeUserDefaults(suiteName: "swiftstash.tests.container.scope.\(UUID().uuidString)")
            let (container, cleanupContainer) = makeUserDefaults(suiteName: "swiftstash.tests.container.own.\(UUID().uuidString)")
            defer {
                cleanupApp()
                cleanupScoped()
                cleanupContainer()
            }

            SwiftStash.configureUserDefaults(app)
            SwiftStash.configureUserDefaults(scoped, for: .testScope)

            final class ScopedContainer: StashContainer {
                let stashStore: StashStore
                @Stash(.containerScopedCount) var scopedCount: Int
                @Stash(.containerCount) var count: Int

                init(_ userDefaults: UserDefaults) {
                    stashStore = StashStore(userDefaults)
                }
            }

            let settings = ScopedContainer(container)
            settings.scopedCount = 30
            settings.count = 31

            #expect(container.integer(forKey: TestScopedKey.counter.rawValue) == 30)
            #expect(container.integer(forKey: "containerTests_count") == 31)
            #expect(scoped.object(forKey: TestScopedKey.counter.rawValue) == nil)
            #expect(app.object(forKey: "containerTests_count") == nil)
        }
    }
}
