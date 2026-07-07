//
//  LoggingTests.swift
//  SwiftStash
//
// Copyright (c) 2026 SwiftStash contributors
// SPDX-License-Identifier: MIT
//

import Foundation
import Testing
@testable import SwiftStash

/// Tests for the SwiftStash logging system.
///
/// Tests cover:
/// - Log level filtering semantics (`shouldLog`)
/// - `SwiftStash.logLevel` configuration and thread-safety
/// - Event routing from @Stash operations to the UserDefaults logging category
///   (via the package-internal `Logging.setEventObserver` hook)
///
/// Note: `logLevel` filters only what reaches OSLog — logging *events* are always
/// recorded to the observer, so filtering is tested via `shouldLog`, and routing
/// via the observer. The keychain-side counterpart lives in `SecureStashTests`.
struct LoggingTests {

    // MARK: - Level Filtering Semantics

    @Test
    func `StashLogLevel minimal filters out normal and verbose`() {
        let level = StashLogLevel.minimal

        #expect(level.shouldLog(messageLevel: .minimal) == true)
        #expect(level.shouldLog(messageLevel: .normal) == false)
        #expect(level.shouldLog(messageLevel: .verbose) == false)
    }

    @Test
    func `StashLogLevel normal allows minimal and normal but filters verbose`() {
        let level = StashLogLevel.normal

        #expect(level.shouldLog(messageLevel: .minimal) == true)
        #expect(level.shouldLog(messageLevel: .normal) == true)
        #expect(level.shouldLog(messageLevel: .verbose) == false)
    }

    @Test
    func `StashLogLevel verbose allows all log levels`() {
        let level = StashLogLevel.verbose

        #expect(level.shouldLog(messageLevel: .minimal) == true)
        #expect(level.shouldLog(messageLevel: .normal) == true)
        #expect(level.shouldLog(messageLevel: .verbose) == true)
    }

    // MARK: - Configuration

    @Test
    func `SwiftStash logLevel reflects runtime changes immediately`() {
        defer { SwiftStash.logLevel = .minimal }

        SwiftStash.logLevel = .normal
        #expect(SwiftStash.logLevel == .normal)

        SwiftStash.logLevel = .verbose
        #expect(SwiftStash.logLevel == .verbose)

        SwiftStash.logLevel = .minimal
        #expect(SwiftStash.logLevel == .minimal)
    }

    @Test
    func `SwiftStash logLevel configuration is thread-safe`() async {
        SwiftStash.logLevel = .minimal
        defer { SwiftStash.logLevel = .minimal }

        await withTaskGroup(of: Void.self) { group in
            for i in 0..<100 {
                group.addTask {
                    let level: StashLogLevel = i % 3 == 0 ? .minimal : (i % 3 == 1 ? .normal : .verbose)
                    SwiftStash.logLevel = level
                    _ = SwiftStash.logLevel
                }
            }
        }

        let finalLevel = SwiftStash.logLevel
        #expect([StashLogLevel.minimal, .normal, .verbose].contains(finalLevel))
    }

    @Test
    func `Concurrent Stash operations with logging are thread-safe`() async {
        SwiftStash.logLevel = .verbose
        defer { SwiftStash.logLevel = .minimal }

        let (userDefaults, cleanup) = makeUserDefaults(suiteName: UUID().uuidString)
        defer { cleanup() }

        let storage = TestStorage(userDefaults: userDefaults)

        await withTaskGroup(of: Void.self) { group in
            // Concurrent writes
            for i in 0..<50 {
                group.addTask {
                    storage.stringValue = "value-\(i)"
                    storage.intValue = i
                    storage.boolValue = i % 2 == 0
                }
            }

            // Concurrent reads
            for _ in 0..<50 {
                group.addTask {
                    _ = storage.stringValue
                    _ = storage.intValue
                    _ = storage.boolValue
                }
            }
        }

        // Verify final state is consistent (one of the written values)
        let finalValue = storage.stringValue
        let finalInt = storage.intValue
        let finalBool = storage.boolValue

        #expect(finalValue.hasPrefix("value-"))
        #expect(finalInt >= 0 && finalInt < 50)
        #expect([true, false].contains(finalBool))
    }

    // MARK: - Event Routing

    @Test
    func `Primitive Stash operations route operation events to UserDefaults logging`() {
        runWithLoggingObserver { collector in
            let (userDefaults, cleanup) = makeUserDefaults(suiteName: UUID().uuidString)
            defer { cleanup() }

            let key = "logging-route-primitive-\(UUID().uuidString)"
            let stash = Stash<String?>(key: key, userDefaults: userDefaults)

            stash.wrappedValue = "value"
            _ = stash.wrappedValue
            stash.wrappedValue = nil

            let events = collector.events.filter { $0.key == key }
            #expect(events.isEmpty == false)
            #expect(events.contains { $0.kind == .operation })
            #expect(events.allSatisfy { $0.storageType == .userDefaults })
        }
    }

    @Test
    func `Codable Stash operations route coding and error events to UserDefaults logging`() {
        runWithLoggingObserver { collector in
            let (userDefaults, cleanup) = makeUserDefaults(suiteName: UUID().uuidString)
            defer { cleanup() }

            let key = "logging-route-codable-\(UUID().uuidString)"
            let fallback = UserProfile(name: "Default", age: 0, email: "default@example.com")
            let stash = Stash<UserProfile>(codable: key, defaultValue: fallback, userDefaults: userDefaults)

            stash.wrappedValue = UserProfile(name: "Alice", age: 30, email: "alice@example.com")
            _ = stash.wrappedValue

            // Corrupt the payload so the next read fails to decode.
            userDefaults.set(Data("not valid json".utf8), forKey: key)
            #expect(stash.wrappedValue == fallback)

            let events = collector.events.filter { $0.key == key }
            #expect(events.contains { $0.kind == .operation })
            #expect(events.contains { $0.kind == .coding })
            #expect(events.contains { $0.kind == .error })
            #expect(events.allSatisfy { $0.storageType == .userDefaults })
        }
    }

    @Test
    func `Encoding failure routes an error event and no operation event`() {
        runWithLoggingObserver { collector in
            let (userDefaults, cleanup) = makeUserDefaults(suiteName: UUID().uuidString)
            defer { cleanup() }

            let storage = FailingEncodableStorage(userDefaults: userDefaults)

            storage.failingValue = FailingEncodable()

            let events = collector.events.filter { $0.key == FailingEncodableStorage.failingValueKey }
            #expect(events.contains { $0.kind == .error })
            // The write is skipped, so no SET operation is recorded.
            #expect(events.contains { $0.kind == .operation } == false)
        }
    }
}
