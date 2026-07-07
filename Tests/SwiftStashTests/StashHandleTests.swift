//
//  StashHandleTests.swift
//  SwiftStash
//
// Copyright (c) 2026 SwiftStash contributors
// SPDX-License-Identifier: MIT
//

import Foundation
import Testing
@testable import SwiftStash

private enum ObservedKey: String {
    case counter
}

// KVO delivers synchronously on the writing thread, so counting is deterministic.
private final class ObservationCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var _count = 0
    var count: Int { lock.lock(); defer { lock.unlock() }; return _count }
    func increment() { lock.lock(); defer { lock.unlock() }; _count += 1 }
}

struct StashHandleTests {

    // MARK: - Existence

    @Test
    func `exists is false before a write and true after`() {
        let (userDefaults, cleanup) = makeUserDefaults(suiteName: UUID().uuidString)
        defer { cleanup() }

        let stash = Stash<Int>(key: "handle:exists", defaultValue: 0, userDefaults: userDefaults)

        #expect(stash.projectedValue.exists == false)

        stash.wrappedValue = 1

        #expect(stash.projectedValue.exists)
    }

    @Test
    func `exists distinguishes a stored default from nothing stored`() {
        let (userDefaults, cleanup) = makeUserDefaults(suiteName: UUID().uuidString)
        defer { cleanup() }

        let stash = Stash<Int>(key: "handle:storedDefault", defaultValue: 7, userDefaults: userDefaults)

        #expect(stash.wrappedValue == 7)
        #expect(stash.projectedValue.exists == false)

        stash.wrappedValue = 7

        #expect(stash.wrappedValue == 7)
        #expect(stash.projectedValue.exists)
    }

    @Test
    func `projected value works through the dollar syntax in a wrapper declaration`() {
        let (userDefaults, cleanup) = makeUserDefaults(suiteName: UUID().uuidString)
        defer { cleanup() }

        struct Container {
            @Stash var count: Int

            init(userDefaults: UserDefaults) {
                _count = Stash(key: "handle:dollar", defaultValue: 0, userDefaults: userDefaults)
            }
        }

        let container = Container(userDefaults: userDefaults)

        #expect(container.$count.exists == false)
        #expect(container.$count.key == "handle:dollar")

        container.count = 3

        #expect(container.$count.exists)
    }

    // MARK: - Removal

    @Test
    func `remove deletes the key and reads fall back to the default`() {
        let (userDefaults, cleanup) = makeUserDefaults(suiteName: UUID().uuidString)
        defer { cleanup() }

        let stash = Stash<String>(key: "handle:remove", defaultValue: "fallback", userDefaults: userDefaults)

        stash.wrappedValue = "stored"
        #expect(stash.projectedValue.exists)

        stash.projectedValue.remove()

        #expect(stash.projectedValue.exists == false)
        #expect(stash.wrappedValue == "fallback")
        #expect(userDefaults.object(forKey: "handle:remove") == nil)
    }

    @Test
    func `remove works for codable stashes`() {
        let (userDefaults, cleanup) = makeUserDefaults(suiteName: UUID().uuidString)
        defer { cleanup() }

        let defaultProfile = UserProfile(name: "Default", age: 0, email: "d@example.com")
        let stash = Stash<UserProfile>(codable: "handle:codable", defaultValue: defaultProfile, userDefaults: userDefaults)

        stash.wrappedValue = UserProfile(name: "Stored", age: 1, email: "s@example.com")
        #expect(stash.projectedValue.exists)

        stash.projectedValue.remove()

        #expect(stash.projectedValue.exists == false)
        #expect(stash.wrappedValue == defaultProfile)
    }

    // MARK: - Handle Updates

    @Test
    func `updates yields the current value first and then every change`() async {
        let (userDefaults, cleanup) = makeUserDefaults(suiteName: UUID().uuidString)
        defer { cleanup() }

        let stash = Stash<Int>(key: "handleUpdates", defaultValue: 0, userDefaults: userDefaults)

        var iterator = stash.projectedValue.updates.makeAsyncIterator()

        #expect(await iterator.next() == 0)

        stash.wrappedValue = 1
        #expect(await iterator.next() == 1)

        stash.wrappedValue = 2
        #expect(await iterator.next() == 2)
    }

    @Test
    func `updates observes writes made directly to UserDefaults`() async {
        let (userDefaults, cleanup) = makeUserDefaults(suiteName: UUID().uuidString)
        defer { cleanup() }

        let stash = Stash<String>(key: "handleExternal", defaultValue: "default", userDefaults: userDefaults)

        var iterator = stash.projectedValue.updates.makeAsyncIterator()

        #expect(await iterator.next() == "default")

        userDefaults.set("external", forKey: "handleExternal")

        #expect(await iterator.next() == "external")
    }

    @Test
    func `updates yields decoded Codable values`() async {
        let (userDefaults, cleanup) = makeUserDefaults(suiteName: UUID().uuidString)
        defer { cleanup() }

        let fallback = UserProfile(name: "Default", age: 0, email: "d@example.com")
        let stash = Stash<UserProfile>(codable: "handleCodableUpdates", defaultValue: fallback, userDefaults: userDefaults)

        var iterator = stash.projectedValue.updates.makeAsyncIterator()

        #expect(await iterator.next() == fallback)

        let stored = UserProfile(name: "Stored", age: 1, email: "s@example.com")
        stash.wrappedValue = stored

        #expect(await iterator.next() == stored)
    }

    @Test
    func `updates yields RawRepresentable enum values`() async {
        let (userDefaults, cleanup) = makeUserDefaults(suiteName: UUID().uuidString)
        defer { cleanup() }

        let stash = Stash<Theme>(key: "handleEnumUpdates", defaultValue: .system, userDefaults: userDefaults)

        var iterator = stash.projectedValue.updates.makeAsyncIterator()

        #expect(await iterator.next() == .system)

        stash.wrappedValue = .dark

        #expect(await iterator.next() == .dark)
    }

    // MARK: - Buffering Policies

    // The stream registers its observer and yields the initial value as soon as it
    // is created, and KVO delivers synchronously on the writing thread — so writing
    // before the first `next()` deterministically exercises the buffer.

    @Test
    func `default buffering coalesces a burst of writes to the newest value`() async {
        let (userDefaults, cleanup) = makeUserDefaults(suiteName: UUID().uuidString)
        defer { cleanup() }

        let stash = Stash<Int>(key: "bufferCoalesce", defaultValue: 0, userDefaults: userDefaults)

        let stream = stash.projectedValue.updates

        stash.wrappedValue = 1
        stash.wrappedValue = 2
        stash.wrappedValue = 3

        // .bufferingNewest(1): the initial 0 and the intermediate 1, 2 are dropped.
        var iterator = stream.makeAsyncIterator()
        #expect(await iterator.next() == 3)
    }

    @Test
    func `unbounded buffering replays every intermediate value`() async {
        let (userDefaults, cleanup) = makeUserDefaults(suiteName: UUID().uuidString)
        defer { cleanup() }

        let stash = Stash<Int>(key: "bufferUnbounded", defaultValue: 0, userDefaults: userDefaults)

        let stream = stash.projectedValue.updates(bufferingPolicy: .unbounded)

        stash.wrappedValue = 1
        stash.wrappedValue = 2
        stash.wrappedValue = 3

        var iterator = stream.makeAsyncIterator()
        #expect(await iterator.next() == 0)
        #expect(await iterator.next() == 1)
        #expect(await iterator.next() == 2)
        #expect(await iterator.next() == 3)
    }

    // MARK: - SwiftStash.updates

    @Test
    func `updates(forKey:) fires once per change of the observed key`() async {
        let (userDefaults, cleanup) = makeUserDefaults(suiteName: UUID().uuidString)
        defer { cleanup() }

        var iterator = SwiftStash.updates(forKey: "observedKey", in: userDefaults).makeAsyncIterator()

        userDefaults.set(1, forKey: "observedKey")
        #expect(await iterator.next() != nil)

        userDefaults.removeObject(forKey: "observedKey")
        #expect(await iterator.next() != nil)
    }

    @Test
    func `key observer does not fire for other keys`() {
        let (userDefaults, cleanup) = makeUserDefaults(suiteName: UUID().uuidString)
        defer { cleanup() }

        let counter = ObservationCounter()
        let observer = UserDefaultsKeyObserver(store: userDefaults, key: "watched") {
            counter.increment()
        }

        userDefaults.set(1, forKey: "unrelated")
        userDefaults.set("x", forKey: "alsoUnrelated")
        userDefaults.set(1, forKey: "watched")

        #expect(counter.count == 1)
        _ = observer
    }

    @Test
    func `key observer does not fire on creation for an already-set key`() {
        let (userDefaults, cleanup) = makeUserDefaults(suiteName: UUID().uuidString)
        defer { cleanup() }

        userDefaults.set(1, forKey: "preexisting")

        let counter = ObservationCounter()
        let observer = UserDefaultsKeyObserver(store: userDefaults, key: "preexisting") {
            counter.increment()
        }

        // Unlike `$prop.updates`, key observation has no initial fire — this is
        // what makes `SwiftStash.updates(forKey:)` yield only on change.
        #expect(counter.count == 0)

        userDefaults.set(2, forKey: "preexisting")

        #expect(counter.count == 1)
        _ = observer
    }

    @Test
    func `Keys containing dots store values but are not observed`() {
        let (userDefaults, cleanup) = makeUserDefaults(suiteName: UUID().uuidString)
        defer { cleanup() }

        // Pitfall: KVO interprets dots as key paths, so observation of a dotted
        // key silently never fires. Storage itself is unaffected.
        let counter = ObservationCounter()
        let observer = UserDefaultsKeyObserver(store: userDefaults, key: "dotted.key") {
            counter.increment()
        }

        let stash = Stash<String>(key: "dotted.key", defaultValue: "", userDefaults: userDefaults)
        stash.wrappedValue = "stored"

        #expect(stash.wrappedValue == "stored")
        #expect(userDefaults.string(forKey: "dotted.key") == "stored")
        #expect(counter.count == 0)
        _ = observer
    }

    @Test
    func `updates(forKey:) accepts a string-backed key enum`() async {
        let (userDefaults, cleanup) = makeUserDefaults(suiteName: UUID().uuidString)
        defer { cleanup() }

        var iterator = SwiftStash.updates(forKey: ObservedKey.counter, in: userDefaults).makeAsyncIterator()

        userDefaults.set(41, forKey: ObservedKey.counter.rawValue)

        #expect(await iterator.next() != nil)
    }
}
