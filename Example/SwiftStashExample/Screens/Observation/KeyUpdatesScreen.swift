//
//  KeyUpdatesScreen.swift
//  SwiftStashExample
//
// Copyright (c) 2026 SwiftStash contributors
// SPDX-License-Identifier: MIT
//

import SwiftUI
import SwiftStash

/// Wrapper-free observation: `SwiftStash.updates(forKey:)` watches **any** UserDefaults
/// key without owning a `@Stash` for it.
///
/// Semantics differ from `$property.updates` in one important way: this stream yields
/// **only on change** — there is no initial element. When syncing state, read the value
/// once before starting the loop.
///
/// The second section demonstrates the dotted-key pitfall: keys containing `.` store
/// fine but can never be observed, because KVO interprets them as key paths.
struct KeyUpdatesScreen: View {

    @State private var events: [String] = []
    @State private var dottedEvents = 0
    @State private var dottedWrites = 0

    var body: some View {
        Form {
            Section {
                Button("Write via raw UserDefaults.set") {
                    UserDefaults.standard.set(Int.random(in: 1...999), forKey: "watchedKey")
                }
                Button("Remove key") {
                    UserDefaults.standard.removeObject(forKey: "watchedKey")
                }
                Text(events.isEmpty ? "No events yet — and none on arrival: this stream has no initial element." : events.joined(separator: "\n"))
                    .font(.footnote.monospaced())
            } header: {
                Text("Observing \"watchedKey\"")
            } footer: {
                Text("The writes bypass SwiftStash entirely, yet the stream fires — observation is per-key KVO on the UserDefaults instance itself.")
            }

            Section {
                Button("Write to \"dotted.key\"") {
                    dottedWrites += 1
                    UserDefaults.standard.set(dottedWrites, forKey: "dotted.key")
                }
                LabeledContent("Writes", value: "\(dottedWrites)")
                LabeledContent("Events received", value: "\(dottedEvents)")
            } header: {
                Text("Pitfall: dots in keys")
            } footer: {
                Text("The value is stored (relaunch and the write count would survive), but the observer never fires — KVO reads \"dotted.key\" as a key path. Use dot-free keys when you need observation.")
            }
        }
        .navigationTitle("updates(forKey:)")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            for await _ in SwiftStash.updates(forKey: "watchedKey") {
                let value = UserDefaults.standard.object(forKey: "watchedKey").map { "\($0)" } ?? "nil"
                events.append("changed → \(value)")
            }
        }
        .task {
            for await _ in SwiftStash.updates(forKey: "dotted.key") {
                dottedEvents += 1  // never reached
            }
        }
    }
}

#Preview {
    NavigationStack { KeyUpdatesScreen() }
}
