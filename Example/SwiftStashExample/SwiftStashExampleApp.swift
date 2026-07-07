//
//  SwiftStashExampleApp.swift
//  SwiftStashExample
//
// Copyright (c) 2026 SwiftStash contributors
// SPDX-License-Identifier: MIT
//

import SwiftUI
import SwiftStash

/// The one-time SwiftStash configuration lives in `App.init()` — before any view
/// (and therefore any property wrapper) is created.
///
/// Each `configure…` call is independent; only add the ones your app needs:
/// - `configureKeychain(service:)` is **mandatory** before the first `@SecureStash`
///   without an explicit `service:` initialises. Instance properties initialise together
///   with their container, so "at launch" really means here, not in `onAppear`.
/// - `configureLogging(level:)` is optional; `.minimal` is the default.
/// - `configureUserDefaults(suiteName:)` is only needed for App Groups — see the
///   "App Groups & iCloud Sync" screen for the full story.
@main
struct SwiftStashExampleApp: App {

    init() {
        SwiftStash.configureKeychain(
            service: ExampleKeychain.service,
            // The library default is .whenPasscodeSetThisDeviceOnly — the most secure
            // option, but items are unreadable on devices without a passcode. For a
            // broad consumer app, pass .whenUnlockedThisDeviceOnly explicitly.
            accessibility: .whenUnlockedThisDeviceOnly
        )

        // Restore the log level chosen on the Logging screen. Using `Stash` directly
        // (not the SwiftUI wrapper) — plain Foundation code, no view context needed.
        let storedLogLevel = Stash(key: "logLevel", defaultValue: StashLogLevel.normal)
        SwiftStash.configureLogging(level: storedLogLevel.wrappedValue)
    }

    var body: some Scene {
        WindowGroup {
            MainView()
        }
    }
}
