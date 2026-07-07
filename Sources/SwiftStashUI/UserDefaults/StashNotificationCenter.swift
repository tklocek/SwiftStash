//
//  StashNotificationCenter.swift
//  SwiftStash
//
// Copyright (c) 2026 SwiftStash contributors
// SPDX-License-Identifier: MIT
//

import Foundation
import Combine
import SwiftStash

/// Multicasts per-key UserDefaults change events to `@Stashed` observers.
///
/// Subscriptions are reference-counted: the KVO observation (which retains the
/// `UserDefaults` instance) and the subject are torn down when the last subscriber
/// cancels, so suites and keys used transiently don't accumulate forever.
@MainActor
final class StashNotificationCenter {
    static let shared = StashNotificationCenter()

    private var keyPublishers: [StoreKeyPair: PassthroughSubject<Void, Never>] = [:]
    private var kvoObservers: [StoreKeyPair: UserDefaultsKeyObserver] = [:]
    private var subscriberCounts: [StoreKeyPair: Int] = [:]

    private init() {}

    func publisher(for key: String, in store: UserDefaults) -> AnyPublisher<Void, Never> {
        let pair = StoreKeyPair(store: store, key: key)

        let subject: PassthroughSubject<Void, Never>
        if let existing = keyPublishers[pair] {
            subject = existing
        } else {
            subject = PassthroughSubject()
            keyPublishers[pair] = subject
            startObservingKey(pair)
        }

        return subject
            .handleEvents(
                receiveSubscription: { _ in
                    // Subscriptions only happen from @MainActor observer inits,
                    // synchronously on this actor.
                    MainActor.assumeIsolated {
                        StashNotificationCenter.shared.retain(pair)
                    }
                },
                receiveCancel: {
                    // Cancellation can come from a deinit on any thread; hop back.
                    Task { @MainActor in
                        StashNotificationCenter.shared.release(pair)
                    }
                }
            )
            .eraseToAnyPublisher()
    }

    func notify(key: String, in store: UserDefaults) {
        let pair = StoreKeyPair(store: store, key: key)
        keyPublishers[pair]?.send()
    }

    private func retain(_ pair: StoreKeyPair) {
        subscriberCounts[pair, default: 0] += 1
    }

    private func release(_ pair: StoreKeyPair) {
        let remaining = (subscriberCounts[pair] ?? 1) - 1
        if remaining > 0 {
            subscriberCounts[pair] = remaining
        } else {
            subscriberCounts[pair] = nil
            keyPublishers[pair] = nil
            kvoObservers[pair] = nil
        }
    }

    private func startObservingKey(_ pair: StoreKeyPair) {
        guard kvoObservers[pair] == nil, let store = pair.store else { return }

        let kvoObserver = UserDefaultsKeyObserver(store: store, key: pair.key) {
            Task { @MainActor in
                StashNotificationCenter.shared.keyPublishers[pair]?.send()
            }
        }

        kvoObservers[pair] = kvoObserver
    }
}

// `@unchecked` because of the weak `UserDefaults` reference: the class itself is
// documented as thread-safe but not annotated `Sendable` in the SDK.
private struct StoreKeyPair: Hashable, @unchecked Sendable {
    let storeId: ObjectIdentifier
    let key: String

    weak var store: UserDefaults?

    init(store: UserDefaults, key: String) {
        self.storeId = ObjectIdentifier(store)
        self.key = key
        self.store = store
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(storeId)
        hasher.combine(key)
    }

    static func == (lhs: StoreKeyPair, rhs: StoreKeyPair) -> Bool {
        lhs.storeId == rhs.storeId && lhs.key == rhs.key
    }
}
