//
//  TestHelpers.swift
//  SwiftStash
//
// Copyright (c) 2026 SwiftStash contributors
// SPDX-License-Identifier: MIT
//

import Combine
import Foundation
@testable import SwiftStash

// MARK: - Test Fixture Creation

/// Creates a TestStorage instance with isolated UserDefaults.
/// - Parameter suiteName: Optional suite name (defaults to unique UUID).
/// - Returns: A tuple containing the test storage and cleanup closure.
///
/// Usage:
/// ```swift
/// @Test
/// func `Test description`() {
///     let (sut, cleanup) = makeTestStorage()
///     defer { cleanup() }
///
///     // Test code here
/// }
/// ```
func makeTestStorage(
    suiteName: String = UUID().uuidString
) -> (sut: TestStorage, cleanup: @Sendable () -> Void) {
    let (userDefaults, cleanup) = makeUserDefaults(suiteName: suiteName)
    let sut = TestStorage(userDefaults: userDefaults)
    return (sut, cleanup)
}

/// Creates an isolated UserDefaults instance for testing.
/// - Parameter suiteName: The suite name for the UserDefaults.
/// - Returns: A tuple containing the UserDefaults and cleanup closure.
func makeUserDefaults(
    suiteName: String
) -> (userDefaults: UserDefaults, cleanup: @Sendable () -> Void) {
    let userDefaults = UserDefaults(suiteName: suiteName)!
    userDefaults.removePersistentDomain(forName: suiteName)

    let cleanup: @Sendable () -> Void = { [suiteName] in
        UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName)
    }

    return (userDefaults, cleanup)
}

// MARK: - Asynchronous Delivery

/// Subscribes to `publisher` immediately and buffers everything it emits, so a test can
/// subscribe, trigger a change, and then await the delivery without missing it.
func values<P: Publisher>(of publisher: P) -> AsyncStream<P.Output> where P.Failure == Never, P.Output: Sendable {
    AsyncStream { continuation in
        let subscription = SubscriptionBox(publisher.sink { continuation.yield($0) })
        continuation.onTermination = { _ in subscription.cancel() }
    }
}

extension AsyncStream where Element: Sendable {
    /// Awaits the first element that satisfies `predicate`; `nil` only if the stream finishes.
    func firstValue(where predicate: @Sendable (Element) -> Bool) async -> Element? {
        for await element in self where predicate(element) {
            return element
        }
        return nil
    }
}

/// `@unchecked` because `AnyCancellable` is not annotated `Sendable`; `cancel()` is thread-safe.
private final class SubscriptionBox: @unchecked Sendable {
    private let cancellable: AnyCancellable

    init(_ cancellable: AnyCancellable) {
        self.cancellable = cancellable
    }

    func cancel() {
        cancellable.cancel()
    }
}

// MARK: - Keychain Mock Backend

/// Serialises access to process-wide test state: the `KeychainRuntime.shared`
/// backend swap and the `Logging` event observer. Every helper that mutates
/// either must take this same lock.
private let processGlobalStateLock = NSLock()

/// Runs `body` against an in-memory keychain backend, so tests never touch the
/// real keychain. The backend swap is process-wide, hence the lock.
/// Do not nest with `runWithLoggingObserver` — the lock is not recursive.
func runWithMockBackend(_ body: (InMemoryKeychainBackend) throws -> Void) rethrows {
    processGlobalStateLock.lock()
    defer { processGlobalStateLock.unlock() }

    let backend = InMemoryKeychainBackend()
    KeychainRuntime.shared.setBackend(backend)
    defer { KeychainRuntime.shared.resetBackend() }

    try body(backend)
}

// MARK: - Logging Event Observation

/// Collects `LoggingEvent`s emitted through the package-internal observer hook.
final class LoggingEventCollector: @unchecked Sendable {
    private let lock = NSLock()
    private var storedEvents: [LoggingEvent] = []

    var events: [LoggingEvent] {
        lock.lock()
        defer { lock.unlock() }
        return storedEvents
    }

    func append(_ event: LoggingEvent) {
        lock.lock()
        defer { lock.unlock() }
        storedEvents.append(event)
    }
}

/// Installs a process-wide logging event observer for the duration of `body`.
/// Uses the same lock as `runWithMockBackend`, because keychain tests also
/// install the observer while holding it. Do not nest the two helpers.
func runWithLoggingObserver(_ body: (LoggingEventCollector) throws -> Void) rethrows {
    processGlobalStateLock.lock()
    defer { processGlobalStateLock.unlock() }

    let collector = LoggingEventCollector()
    Logging.setEventObserver { collector.append($0) }
    defer { Logging.setEventObserver(nil) }

    try body(collector)
}

/// Returns a unique keychain service name so tests cannot collide on keys.
func makeSecureService(prefix: String) -> String {
    "\(prefix).\(UUID().uuidString)"
}
