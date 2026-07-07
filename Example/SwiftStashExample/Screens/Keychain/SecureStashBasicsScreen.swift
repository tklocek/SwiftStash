//
//  SecureStashBasicsScreen.swift
//  SwiftStashExample
//
// Copyright (c) 2026 SwiftStash contributors
// SPDX-License-Identifier: MIT
//

import SwiftUI
import SwiftStash

/// `@SecureStash` fundamentals: the same property syntax as `@Stash`, backed by the
/// Keychain.
///
/// Rules that differ from UserDefaults, all visible on this screen:
/// - Values are **always optional** — non-optional keychain values are unsupported by
///   design. Assigning `nil` deletes the item.
/// - Reads and writes never throw from the wrapper; failures are logged (OSLog) and
///   reads return `nil`. Use `KeychainManager` when you need thrown errors.
/// - The projected value is a `SecureStashHandle`: `exists` (a presence probe — no
///   decode), `remove()`, and `key`. There is no `updates` stream: the keychain has
///   no change-notification mechanism.
struct SecureStashBasicsScreen: View {

    @SecureStash(key: SharedKey.authToken) private var token: String?
    @SecureStash(key: "rawSecret") private var secret: Data?

    @State private var draft = ""
    @State private var tokenValue: String?
    @State private var tokenExists = false
    @State private var secretDescription = "nil"

    var body: some View {
        Form {
            Section {
                LabeledContent("Value", value: tokenValue ?? "nil")
                LabeledContent("$token.exists", value: tokenExists ? "true" : "false")
                TextField("New token", text: $draft)
                Button("Save") {
                    token = draft
                    refresh()
                }
                Button("Assign nil (deletes the item)", role: .destructive) {
                    token = nil
                    refresh()
                }
                Button("$token.remove()", role: .destructive) {
                    $token.remove()
                    refresh()
                }
            } header: {
                Text("String? · \(SharedKey.authToken.rawValue)")
            } footer: {
                Text("Same key as the token on the adoption screens. exists probes presence without reading or decoding the payload.")
            }

            Section {
                LabeledContent("Value", value: secretDescription)
                Button("Store 32 random bytes") {
                    secret = Data((0..<32).map { _ in UInt8.random(in: .min ... .max) })
                    refresh()
                }
                Button("Delete", role: .destructive) {
                    secret = nil
                    refresh()
                }
            } header: {
                Text("Data?")
            }
        }
        .navigationTitle("@SecureStash")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: refresh)
    }

    private func refresh() {
        tokenValue = token
        tokenExists = $token.exists
        draft = token ?? ""
        secretDescription = secret.map { "\($0.count) bytes · \($0.prefix(4).map { String(format: "%02x", $0) }.joined())…" } ?? "nil"
    }
}

#Preview {
    NavigationStack { SecureStashBasicsScreen() }
}
