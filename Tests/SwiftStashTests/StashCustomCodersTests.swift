//
//  StashCustomCodersTests.swift
//  SwiftStash
//
// Copyright (c) 2026 SwiftStash contributors
// SPDX-License-Identifier: MIT
//

import Foundation
import Testing
@testable import SwiftStash

private struct Meeting: Codable, Equatable, Sendable {
    var title: String
    var startsAt: Date
}

private struct SnakeCasedProfile: Codable, Equatable, Sendable {
    var firstName: String
    var lastName: String
}

@Suite("Stash custom coders")
struct StashCustomCodersTests {

    private static func iso8601Coders() -> (JSONEncoder, JSONDecoder) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (encoder, decoder)
    }

    @Test
    func `Custom date strategy round-trips through the wrapper`() {
        let (userDefaults, cleanup) = makeUserDefaults(suiteName: "custom.coders.date.roundtrip")
        defer { cleanup() }

        let (encoder, decoder) = Self.iso8601Coders()
        let stash = Stash(
            codable: "meeting",
            defaultValue: Meeting(title: "", startsAt: .distantPast),
            userDefaults: userDefaults,
            encoder: encoder,
            decoder: decoder
        )

        // ISO-8601 has second precision — use a whole-second date so equality holds.
        let meeting = Meeting(title: "Standup", startsAt: Date(timeIntervalSince1970: 1_750_000_000))
        stash.wrappedValue = meeting

        #expect(stash.wrappedValue == meeting)
    }

    @Test
    func `Custom encoder controls the stored representation`() throws {
        let (userDefaults, cleanup) = makeUserDefaults(suiteName: "custom.coders.date.format")
        defer { cleanup() }

        let (encoder, decoder) = Self.iso8601Coders()
        let stash = Stash(
            codable: "meeting",
            defaultValue: Meeting(title: "", startsAt: .distantPast),
            userDefaults: userDefaults,
            encoder: encoder,
            decoder: decoder
        )

        stash.wrappedValue = Meeting(title: "Standup", startsAt: Date(timeIntervalSince1970: 0))

        let data = try #require(userDefaults.data(forKey: "meeting"))
        let json = try #require(String(data: data, encoding: .utf8))
        #expect(json.contains("1970-01-01T00:00:00Z"))
    }

    @Test
    func `Custom key strategy decodes data a default decoder would reject`() throws {
        let (userDefaults, cleanup) = makeUserDefaults(suiteName: "custom.coders.snake.case")
        defer { cleanup() }

        // Seed snake_case JSON, as an external system (or previous manual storage) would.
        let json = #"{"first_name":"Grace","last_name":"Hopper"}"#
        userDefaults.set(Data(json.utf8), forKey: "profile")

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase

        let fallback = SnakeCasedProfile(firstName: "", lastName: "")
        let stash = Stash(
            codable: "profile",
            defaultValue: fallback,
            userDefaults: userDefaults,
            encoder: encoder,
            decoder: decoder
        )

        #expect(stash.wrappedValue == SnakeCasedProfile(firstName: "Grace", lastName: "Hopper"))

        // A wrapper left on default coders cannot read that payload and falls back.
        let defaultCoders = Stash(codable: "profile", defaultValue: fallback, userDefaults: userDefaults)
        #expect(defaultCoders.wrappedValue == fallback)
    }

    @Test
    func `Custom coders work with the AppStorage-style spelling`() {
        let (userDefaults, cleanup) = makeUserDefaults(suiteName: "custom.coders.appstorage.style")
        defer { cleanup() }

        let (encoder, decoder) = Self.iso8601Coders()
        let meeting = Meeting(title: "Retro", startsAt: Date(timeIntervalSince1970: 1_750_000_000))

        let stash = Stash(
            wrappedValue: Meeting(title: "", startsAt: .distantPast),
            codable: "meeting",
            userDefaults: userDefaults,
            encoder: encoder,
            decoder: decoder
        )
        stash.wrappedValue = meeting

        #expect(stash.wrappedValue == meeting)
    }

    @Test
    func `Optional codable with custom coders removes key on nil`() {
        let (userDefaults, cleanup) = makeUserDefaults(suiteName: "custom.coders.optional.nil")
        defer { cleanup() }

        let (encoder, decoder) = Self.iso8601Coders()
        let stash = Stash<Meeting?>(
            codable: "meeting",
            userDefaults: userDefaults,
            encoder: encoder,
            decoder: decoder
        )

        stash.wrappedValue = Meeting(title: "1:1", startsAt: Date(timeIntervalSince1970: 1_750_000_000))
        #expect(userDefaults.data(forKey: "meeting") != nil)

        stash.wrappedValue = nil
        #expect(userDefaults.data(forKey: "meeting") == nil)
    }
}
