//
//  StashedNotificationIsolationTests.swift
//  SwiftStash
//
// Copyright (c) 2026 SwiftStash contributors
// SPDX-License-Identifier: MIT
//

import Foundation
import Testing
import Combine
import SwiftUI
@testable import SwiftStashUI
@testable import SwiftStash

@MainActor
struct StashedNotificationIsolationTests {

    // MARK: - StashNotificationCenter Isolation

    @Test
    func `Notification center only notifies the specific key that changed`() {
        let (userDefaults, cleanup) = makeUserDefaults(suiteName: "isolation.notification.center")
        defer { cleanup() }

        var keyANotificationCount = 0
        var keyBNotificationCount = 0
        var cancellables = Set<AnyCancellable>()

        StashNotificationCenter.shared
            .publisher(for: "keyA", in: userDefaults)
            .sink { keyANotificationCount += 1 }
            .store(in: &cancellables)

        StashNotificationCenter.shared
            .publisher(for: "keyB", in: userDefaults)
            .sink { keyBNotificationCount += 1 }
            .store(in: &cancellables)

        // Only notify keyA
        StashNotificationCenter.shared.notify(key: "keyA", in: userDefaults)

        // Allow the RunLoop to process notifications
        RunLoop.main.run(mode: .default, before: Date().addingTimeInterval(0.05))

        #expect(keyANotificationCount == 1, "keyA should receive exactly 1 notification")
        #expect(keyBNotificationCount == 0, "keyB should NOT receive any notification when only keyA changed")
    }

    @Test
    func `Updating UserDefaults directly notifies only the changed key`() async {
        let (userDefaults, cleanup) = makeUserDefaults(suiteName: "isolation.broadcast")
        defer { cleanup() }

        var keyANotificationCount = 0
        var keyBNotificationCount = 0
        var cancellables = Set<AnyCancellable>()

        StashNotificationCenter.shared
            .publisher(for: "isoKeyA", in: userDefaults)
            .sink { keyANotificationCount += 1 }
            .store(in: &cancellables)

        StashNotificationCenter.shared
            .publisher(for: "isoKeyB", in: userDefaults)
            .sink { keyBNotificationCount += 1 }
            .store(in: &cancellables)

        // Simulate an external change: write directly to UserDefaults.
        // The per-key KVO observer picks it up and hops to the main actor via
        // Task, so the test must suspend (not spin the run loop, which would
        // hold the actor) for the notification to be delivered.
        userDefaults.set("value", forKey: "isoKeyA")

        for _ in 0..<1000 where keyANotificationCount == 0 {
            await Task.yield()
        }
        // Extra yields so an (incorrect) broadcast to keyB would also land.
        for _ in 0..<10 {
            await Task.yield()
        }

        // Without the positive assertion this test would also pass if external
        // writes notified nobody — both halves are required.
        #expect(keyANotificationCount >= 1, "keyA should be notified when it is updated externally")
        #expect(keyBNotificationCount == 0, "keyB should NOT be notified when keyA is updated externally")
    }

    // MARK: - @Stashed Observer Isolation

    @Test
    func `Changing one Stashed property does not trigger observer for another`() {
        let (userDefaults, cleanup) = makeUserDefaults(suiteName: "isolation.observer")
        defer { cleanup() }

        let sut = StashedIsolationTestView(userDefaults: userDefaults)

        var stringObserverFireCount = 0
        var intObserverFireCount = 0
        var cancellables = Set<AnyCancellable>()

        // Subscribe to notification center for each key to count broadcasts
        StashNotificationCenter.shared
            .publisher(for: "isolationString", in: userDefaults)
            .sink { stringObserverFireCount += 1 }
            .store(in: &cancellables)

        StashNotificationCenter.shared
            .publisher(for: "isolationInt", in: userDefaults)
            .sink { intObserverFireCount += 1 }
            .store(in: &cancellables)

        // Only change the string value
        sut.stringValue = "changed"

        // Allow notification propagation
        RunLoop.main.run(mode: .default, before: Date().addingTimeInterval(0.05))

        #expect(stringObserverFireCount >= 1, "String key should be notified")
        #expect(intObserverFireCount == 0, "Int key should NOT be notified when only string changed")
    }

    @Test
    func `Multiple sequential changes only notify the changed key each time`() {
        let (userDefaults, cleanup) = makeUserDefaults(suiteName: "isolation.sequential")
        defer { cleanup() }

        var keyACount = 0
        var keyBCount = 0
        var keyCCount = 0
        var cancellables = Set<AnyCancellable>()

        StashNotificationCenter.shared
            .publisher(for: "seqKeyA", in: userDefaults)
            .sink { keyACount += 1 }
            .store(in: &cancellables)

        StashNotificationCenter.shared
            .publisher(for: "seqKeyB", in: userDefaults)
            .sink { keyBCount += 1 }
            .store(in: &cancellables)

        StashNotificationCenter.shared
            .publisher(for: "seqKeyC", in: userDefaults)
            .sink { keyCCount += 1 }
            .store(in: &cancellables)

        // Change only keyA, then only keyB
        StashNotificationCenter.shared.notify(key: "seqKeyA", in: userDefaults)
        RunLoop.main.run(mode: .default, before: Date().addingTimeInterval(0.05))

        StashNotificationCenter.shared.notify(key: "seqKeyB", in: userDefaults)
        RunLoop.main.run(mode: .default, before: Date().addingTimeInterval(0.05))

        #expect(keyACount == 1, "keyA should be notified exactly once")
        #expect(keyBCount == 1, "keyB should be notified exactly once")
        #expect(keyCCount == 0, "keyC should never be notified")
    }
}

// MARK: - Isolation Test View

@MainActor
private struct StashedIsolationTestView: View {
    @Stashed var stringValue: String
    @Stashed var intValue: Int
    @Stashed var boolValue: Bool

    var body: some View {
        EmptyView()
    }

    init(userDefaults: UserDefaults) {
        _stringValue = Stashed(key: "isolationString", defaultValue: "", store: userDefaults)
        _intValue = Stashed(key: "isolationInt", defaultValue: 0, store: userDefaults)
        _boolValue = Stashed(key: "isolationBool", defaultValue: false, store: userDefaults)
    }
}
