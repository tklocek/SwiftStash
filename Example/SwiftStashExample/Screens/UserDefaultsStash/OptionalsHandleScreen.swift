//
//  OptionalsHandleScreen.swift
//  SwiftStashExample
//
// Copyright (c) 2026 SwiftStash contributors
// SPDX-License-Identifier: MIT
//

import SwiftUI
import SwiftStash

/// Optionals and the projected value (`$property` → `StashHandle`).
///
/// Two things `@AppStorage` cannot express:
/// - **Optionals with removal semantics**: assigning `nil` removes the key entirely.
/// - **"Never set" vs "set to the default"**: `$property.exists` tells them apart —
///   a stored `0` and no stored value both read as `0`, but only one *exists*.
///
/// The handle also offers `remove()` (delete, fall back to default) and `key`.
struct OptionalsHandleScreen: View {

    @Stash("optionalNickname") private var nickname: String?
    @Stash("handleCounter") private var counter = 0

    // @Stash does not invalidate views — mirror what this screen displays in @State
    // and refresh after every action. (@Stashed does this automatically; using the
    // manual pattern here keeps the handle semantics visible.)
    @State private var draft = ""
    @State private var snapshot = Snapshot()

    private struct Snapshot {
        var nickname: String?
        var nicknameExists = false
        var counter = 0
        var counterExists = false
    }

    var body: some View {
        Form {
            Section {
                LabeledContent("Value", value: snapshot.nickname ?? "nil")
                LabeledContent("$nickname.exists", value: snapshot.nicknameExists ? "true" : "false")
                TextField("New nickname", text: $draft)
                Button("Save") {
                    nickname = draft
                    refresh()
                }
                Button("Assign nil (removes the key)", role: .destructive) {
                    nickname = nil
                    refresh()
                }
            } header: {
                Text("Optional String")
            } footer: {
                Text("After assigning nil the key is gone from UserDefaults — not stored as an empty string.")
            }

            Section {
                LabeledContent("Value", value: "\(snapshot.counter)")
                LabeledContent("$counter.exists", value: snapshot.counterExists ? "true" : "false")
                LabeledContent("$counter.key", value: $counter.key)
                Button("Write current value") {
                    counter = snapshot.counter
                    refresh()
                }
                Button("Increment") {
                    counter += 1
                    refresh()
                }
                Button("$counter.remove()", role: .destructive) {
                    $counter.remove()
                    refresh()
                }
            } header: {
                Text("Non-optional + handle")
            } footer: {
                Text("Write the default value 0 and exists flips to true — the value reads the same, but now it is stored. remove() flips it back.")
            }
        }
        .navigationTitle("Optionals & $handle")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: refresh)
    }

    private func refresh() {
        snapshot = Snapshot(
            nickname: nickname,
            nicknameExists: $nickname.exists,
            counter: counter,
            counterExists: $counter.exists
        )
        draft = nickname ?? ""
    }
}

#Preview {
    NavigationStack { OptionalsHandleScreen() }
}
