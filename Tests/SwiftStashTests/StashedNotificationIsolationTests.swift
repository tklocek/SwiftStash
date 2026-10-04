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

        StashNotificationCenter.shared.notify(key: "keyA", in: userDefaults)


        #expect(keyANotificationCount == 1, "keyA should receive exactly 1 notification")
        #expect(keyBNotificationCount == 0, "keyB should NOT receive any notification when only keyA changed")
    }

    @Test
    func `Updating UserDefaults directly notifies only the changed key`() async {
        let (userDefaults, cleanup) = makeUserDefaults(suiteName: "isolation.broadcast")
        defer { cleanup() }

        var keyBNotificationCount = 0
        var cancellables = Set<AnyCancellable>()

        let keyAEvents = values(of: StashNotificationCenter.shared.publisher(for: "isoKeyA", in: userDefaults))
        let sentinelEvents = values(of: StashNotificationCenter.shared.publisher(for: "isoSentinel", in: userDefaults))

        StashNotificationCenter.shared
            .publisher(for: "isoKeyB", in: userDefaults)
            .sink { keyBNotificationCount += 1 }
            .store(in: &cancellables)

        // Simulate an external change: write directly to UserDefaults. Each write reaches the
        // center in its own main-actor task, in write order, so once the later sentinel write
        // has arrived, an (incorrect) broadcast of keyA's change to keyB would have landed too.
        userDefaults.set("value", forKey: "isoKeyA")
        userDefaults.set("done", forKey: "isoSentinel")

        // Without the positive assertion this test would also pass if external
        // writes notified nobody — both halves are required.
        #expect(await keyAEvents.firstValue { _ in true } != nil, "keyA should be notified when it is updated externally")
        _ = await sentinelEvents.firstValue { _ in true }
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

        StashNotificationCenter.shared
            .publisher(for: "isolationString", in: userDefaults)
            .sink { stringObserverFireCount += 1 }
            .store(in: &cancellables)

        StashNotificationCenter.shared
            .publisher(for: "isolationInt", in: userDefaults)
            .sink { intObserverFireCount += 1 }
            .store(in: &cancellables)

        sut.stringValue = "changed"


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

        StashNotificationCenter.shared.notify(key: "seqKeyA", in: userDefaults)

        StashNotificationCenter.shared.notify(key: "seqKeyB", in: userDefaults)

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
