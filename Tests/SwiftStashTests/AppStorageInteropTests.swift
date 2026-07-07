//
//  AppStorageInteropTests.swift
//  SwiftStash
//
// Copyright (c) 2026 SwiftStash contributors
// SPDX-License-Identifier: MIT
//

import Foundation
import Testing
import SwiftUI
@testable import SwiftStash

/// Locks the core adoption promise: `@Stash` shares the exact storage
/// representation with `@AppStorage`, so both read and write the same keys
/// with no data migration.
///
/// `@AppStorage` reads its value from the store at wrapper init, so each
/// assertion creates the wrapper after the write it verifies — that keeps the
/// tests deterministic outside a rendered SwiftUI view.
@MainActor
struct AppStorageInteropTests {

    @Test
    func `Stash reads a primitive value written by AppStorage`() {
        let (userDefaults, cleanup) = makeUserDefaults(suiteName: UUID().uuidString)
        defer { cleanup() }

        let appStorage = AppStorage(wrappedValue: 0, "interopCount", store: userDefaults)
        appStorage.wrappedValue = 5

        let stash = Stash<Int>(key: "interopCount", defaultValue: 0, userDefaults: userDefaults)
        #expect(stash.wrappedValue == 5)
    }

    @Test
    func `AppStorage reads a primitive value written by Stash`() {
        let (userDefaults, cleanup) = makeUserDefaults(suiteName: UUID().uuidString)
        defer { cleanup() }

        let stash = Stash<String>(key: "interopName", defaultValue: "", userDefaults: userDefaults)
        stash.wrappedValue = "shared"

        let appStorage = AppStorage(wrappedValue: "", "interopName", store: userDefaults)
        #expect(appStorage.wrappedValue == "shared")
    }

    @Test
    func `Enums interoperate through the shared raw-value representation`() {
        let (userDefaults, cleanup) = makeUserDefaults(suiteName: UUID().uuidString)
        defer { cleanup() }

        let stash = Stash<Theme>(key: "interopTheme", defaultValue: .system, userDefaults: userDefaults)
        stash.wrappedValue = .dark

        let appStorage = AppStorage(wrappedValue: Theme.system, "interopTheme", store: userDefaults)
        #expect(appStorage.wrappedValue == .dark)

        appStorage.wrappedValue = .light

        #expect(stash.wrappedValue == .light)
    }
}
