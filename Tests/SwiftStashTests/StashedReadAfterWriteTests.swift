//
//  StashedReadAfterWriteTests.swift
//  SwiftStash
//
// Copyright (c) 2026 SwiftStash contributors
// SPDX-License-Identifier: MIT
//

import Foundation
import Testing
import SwiftUI
import SwiftStashUI

/// A Codable value whose encoding fails for negative numbers.
private struct SometimesEncodable: Codable, Equatable, Sendable {
    var value: Int

    func encode(to encoder: any Encoder) throws {
        struct NegativeValue: Error {}
        guard value >= 0 else { throw NegativeValue() }
        var container = encoder.singleValueContainer()
        try container.encode(value)
    }

    init(_ value: Int) {
        self.value = value
    }

    init(from decoder: any Decoder) throws {
        value = try decoder.singleValueContainer().decode(Int.self)
    }
}

/// Tests that `@Stashed` reads back what the store holds right after a write.
///
/// A write need not round-trip: assigning `nil` to an optional with a non-nil default removes
/// the key, so the store reads back the default; a failed `Codable` encode keeps the previously
/// stored value. `@Stash` reads the store on every access; `@Stashed` must agree immediately,
/// not after its debounced change notification.
@MainActor
struct StashedReadAfterWriteTests {

    @Test
    func `Assigning nil to an optional with a default reads the default immediately`() {
        let (userDefaults, cleanup) = makeUserDefaults(suiteName: "readAfterWrite.nil.\(UUID().uuidString)")
        defer { cleanup() }

        let stashed = Stashed<Int?>(key: "optionalWithDefault", defaultValue: 5, store: userDefaults)
        stashed.wrappedValue = 7
        #expect(stashed.wrappedValue == 7)

        stashed.wrappedValue = nil

        #expect(userDefaults.object(forKey: "optionalWithDefault") == nil)
        #expect(stashed.wrappedValue == 5)
    }

    @Test
    func `Writing nil through the binding reads the default immediately`() {
        let (userDefaults, cleanup) = makeUserDefaults(suiteName: "readAfterWrite.binding.\(UUID().uuidString)")
        defer { cleanup() }

        let stashed = Stashed<Int?>(key: "bindingWithDefault", defaultValue: 5, store: userDefaults)
        let binding = stashed.projectedValue
        binding.wrappedValue = 7

        binding.wrappedValue = nil

        #expect(binding.wrappedValue == 5)
        #expect(stashed.wrappedValue == 5)
    }

    @Test
    func `A failed encode keeps showing the stored value`() {
        let (userDefaults, cleanup) = makeUserDefaults(suiteName: "readAfterWrite.encode.\(UUID().uuidString)")
        defer { cleanup() }

        let stashed = Stashed<SometimesEncodable>(
            codable: "sometimesEncodable",
            defaultValue: SometimesEncodable(0),
            store: userDefaults
        )
        stashed.wrappedValue = SometimesEncodable(3)

        stashed.wrappedValue = SometimesEncodable(-1)

        #expect(stashed.wrappedValue == SometimesEncodable(3))
    }

    #if canImport(AppKit)
    @MainActor
    private final class RenderLog {
        var values: [Int?] = []
        var binding: Binding<Int?>?
    }

    private struct OptionalWithDefaultView: View {
        @Stashed private var value: Int?
        let log: RenderLog

        init(store: UserDefaults, log: RenderLog) {
            _value = Stashed(key: "hostedOptionalWithDefault", defaultValue: 5, store: store)
            self.log = log
        }

        var body: some View {
            log.values.append(value)
            log.binding = $value
            return Text(value.map(String.init) ?? "nil")
        }
    }

    @Test
    func `Hosted view never renders the assigned nil`() {
        let (userDefaults, cleanup) = makeUserDefaults(suiteName: "readAfterWrite.hosted.\(UUID().uuidString)")
        defer { cleanup() }
        userDefaults.set(7, forKey: "hostedOptionalWithDefault")

        let log = RenderLog()
        let host = HostedView(OptionalWithDefaultView(store: userDefaults, log: log))
        #expect(log.values.last == 7)

        log.binding?.wrappedValue = nil
        host.render()

        #expect(log.values.last == 5)
        #expect(log.values.contains(Optional<Int>.none) == false)
    }
    #endif
}
