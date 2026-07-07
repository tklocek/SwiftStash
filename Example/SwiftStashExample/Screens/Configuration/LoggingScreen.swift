//
//  LoggingScreen.swift
//  SwiftStashExample
//
// Copyright (c) 2026 SwiftStash contributors
// SPDX-License-Identifier: MIT
//

import SwiftUI
import SwiftStash
import SwiftStashUI

/// Runtime control of SwiftStash logging. One level drives both subsystems
/// (`@Stash`/UserDefaults and `@SecureStash`/Keychain).
///
/// The chosen level is itself persisted with `@Stashed` and re-applied at launch in
/// `SwiftStashExampleApp.init()` — a nice example of the library configuring itself.
///
/// Privacy: keys are logged as `.private` (redacted outside a debugger), type names and
/// error messages as `.public`. Stored values are never logged at any level.
struct LoggingScreen: View {

    @Stashed("logLevel") private var level: StashLogLevel = .normal

    var body: some View {
        Form {
            Section {
                Picker("Log level", selection: $level) {
                    Text("Minimal — errors only").tag(StashLogLevel.minimal)
                    Text("Normal — errors + operations").tag(StashLogLevel.normal)
                    Text("Verbose — + encode/decode detail").tag(StashLogLevel.verbose)
                }
                .pickerStyle(.inline)
                .onChange(of: level) {
                    SwiftStash.configureLogging(level: level)
                }
            } footer: {
                Text(".minimal is the library default and the production recommendation. The setting persists and is re-applied at every launch.")
            }

            Section {
                Text("Open Console.app (or Xcode's console), filter by subsystem \"SwiftStash\", then use any other screen. Categories: Storage.Operations / .Errors / .Coding for UserDefaults, Keychain.Operations / .Errors / .Coding for the Keychain.")
                    .font(.footnote)
            } header: {
                Text("Watching the logs")
            }
        }
        .navigationTitle("Logging")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack { LoggingScreen() }
}
