//
//  StashURLTests.swift
//  SwiftStash
//
// Copyright (c) 2026 SwiftStash contributors
// SPDX-License-Identifier: MIT
//

import Foundation
import Testing
@testable import SwiftStash

struct StashURLTests {

    @Test
    func `URL Stash round-trips`() {
        let (userDefaults, cleanup) = makeUserDefaults(suiteName: UUID().uuidString)
        defer { cleanup() }

        let fallback = URL(string: "https://fallback.example.com")!
        let stash = Stash<URL>(key: "url.roundtrip", defaultValue: fallback, userDefaults: userDefaults)

        #expect(stash.wrappedValue == fallback)

        let url = URL(string: "https://example.com/path?q=1")!
        stash.wrappedValue = url

        #expect(stash.wrappedValue == url)
    }

    @Test
    func `Optional URL Stash round-trips and clears`() {
        let (userDefaults, cleanup) = makeUserDefaults(suiteName: UUID().uuidString)
        defer { cleanup() }

        let stash = Stash<URL?>(key: "url.optional", userDefaults: userDefaults)

        #expect(stash.wrappedValue == nil)

        let url = URL(fileURLWithPath: "/tmp/example.txt")
        stash.wrappedValue = url

        #expect(stash.wrappedValue == url)

        stash.wrappedValue = nil

        #expect(stash.wrappedValue == nil)
        #expect(userDefaults.object(forKey: "url.optional") == nil)
    }

    @Test
    func `URL is stored in the representation url(forKey:) reads`() {
        let (userDefaults, cleanup) = makeUserDefaults(suiteName: UUID().uuidString)
        defer { cleanup() }

        let url = URL(string: "https://example.com/interop")!
        let stash = Stash<URL?>(key: "url.interop", userDefaults: userDefaults)

        stash.wrappedValue = url

        #expect(userDefaults.url(forKey: "url.interop") == url)
    }
}
