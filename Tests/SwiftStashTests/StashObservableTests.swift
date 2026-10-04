//
//  StashObservableTests.swift
//  SwiftStash
//
// Copyright (c) 2026 SwiftStash contributors
// SPDX-License-Identifier: MIT
//

import Foundation
import Observation
import Testing
@testable import SwiftStash

extension StashKey<Int> {
    fileprivate static var observedCount: Self { .init("observedCount", default: 3) }
}

/// An `@Observable` model holding its store, as an app's view model would.
@available(macOS 14.0, iOS 17.0, tvOS 17.0, watchOS 10.0, *)
@MainActor @Observable
private final class CounterModel: StashObservable, StashContainer {
    @ObservationIgnored let stashStore: StashStore
    @ObservationIgnored @Stash(.observedCount) var count: Int
    var label = ""

    init(_ userDefaults: UserDefaults) {
        stashStore = StashStore(userDefaults)
    }
}

/// Implements the observation requirements by hand, counting what the wrapper reports.
@available(macOS 14.0, iOS 17.0, tvOS 17.0, watchOS 10.0, *)
private final class RecordingModel: StashObservable, StashContainer, @unchecked Sendable {
    let stashStore: StashStore
    @Stash(.observedCount) var count: Int
    private(set) var accesses = 0
    private(set) var mutations = 0

    init(_ userDefaults: UserDefaults) {
        stashStore = StashStore(userDefaults)
    }

    func access<Member>(keyPath: KeyPath<RecordingModel, Member>) {
        accesses += 1
    }

    func withMutation<Member, MutationResult>(
        keyPath: KeyPath<RecordingModel, Member>,
        _ mutation: () throws -> MutationResult
    ) rethrows -> MutationResult {
        mutations += 1
        return try mutation()
    }
}

private final class ChangeCounter: @unchecked Sendable {
    var changes = 0
}

/// Tests for `StashObservable`: `@Stash` properties of an `@Observable` class.
///
/// Tests cover:
/// - reads registered with, and writes reported to, Observation
/// - the value read from the store on every access (no mirror)
/// - writes that bypass the class reaching its observers through key-value observation
/// - one notification per write, whether the class or someone else wrote
/// - a released model leaving no observation behind
///
/// Key-value observation of a write to the same `UserDefaults` instance is delivered
/// synchronously, so none of these tests waits.
@MainActor
struct StashObservableTests {

    @Test
    func `Writes through the model notify observers and reach the store`() {
        guard #available(macOS 14.0, iOS 17.0, tvOS 17.0, watchOS 10.0, *) else { return }
        let (userDefaults, cleanup) = makeUserDefaults(suiteName: "observable.write.\(UUID().uuidString)")
        defer { cleanup() }

        let model = CounterModel(userDefaults)
        let counter = ChangeCounter()
        withObservationTracking { _ = model.count } onChange: { counter.changes += 1 }

        model.count = 9

        #expect(counter.changes == 1)
        #expect(userDefaults.integer(forKey: "observedCount") == 9)
        #expect(model.count == 9)
    }

    @Test
    func `Every read comes from the store`() {
        guard #available(macOS 14.0, iOS 17.0, tvOS 17.0, watchOS 10.0, *) else { return }
        let (userDefaults, cleanup) = makeUserDefaults(suiteName: "observable.read.\(UUID().uuidString)")
        defer { cleanup() }

        let model = CounterModel(userDefaults)
        #expect(model.count == 3)

        userDefaults.set(11, forKey: "observedCount")

        #expect(model.count == 11)
    }

    @Test
    func `Writes that bypass the model notify its observers`() {
        guard #available(macOS 14.0, iOS 17.0, tvOS 17.0, watchOS 10.0, *) else { return }
        let (userDefaults, cleanup) = makeUserDefaults(suiteName: "observable.external.\(UUID().uuidString)")
        defer { cleanup() }

        let model = CounterModel(userDefaults)
        let counter = ChangeCounter()
        withObservationTracking { _ = model.count } onChange: { counter.changes += 1 }

        Stash<Int>(.observedCount, userDefaults: userDefaults).wrappedValue = 12

        #expect(counter.changes == 1)
        #expect(model.count == 12)
    }

    @Test
    func `Each write is reported once, whoever writes`() {
        guard #available(macOS 14.0, iOS 17.0, tvOS 17.0, watchOS 10.0, *) else { return }
        let (userDefaults, cleanup) = makeUserDefaults(suiteName: "observable.once.\(UUID().uuidString)")
        defer { cleanup() }

        let model = RecordingModel(userDefaults)
        _ = model.count
        #expect(model.accesses == 1)
        #expect(model.mutations == 0)

        model.count = 4
        #expect(model.mutations == 1)

        userDefaults.set(5, forKey: "observedCount")
        #expect(model.mutations == 2)
        #expect(model.count == 5)
    }

    @Test
    func `Projected value works on an observable model`() {
        guard #available(macOS 14.0, iOS 17.0, tvOS 17.0, watchOS 10.0, *) else { return }
        let (userDefaults, cleanup) = makeUserDefaults(suiteName: "observable.projected.\(UUID().uuidString)")
        defer { cleanup() }

        let model = CounterModel(userDefaults)
        #expect(model.$count.exists == false)

        model.count = 6
        #expect(model.$count.exists)

        model.$count.remove()
        #expect(model.count == 3)
    }

    @Test
    func `A released model leaves no observation behind`() {
        guard #available(macOS 14.0, iOS 17.0, tvOS 17.0, watchOS 10.0, *) else { return }
        let (userDefaults, cleanup) = makeUserDefaults(suiteName: "observable.released.\(UUID().uuidString)")
        defer { cleanup() }

        weak var released: CounterModel?
        do {
            let model = CounterModel(userDefaults)
            _ = model.count
            released = model
        }

        #expect(released == nil)
        userDefaults.set(7, forKey: "observedCount")
        #expect(userDefaults.integer(forKey: "observedCount") == 7)
    }
}
