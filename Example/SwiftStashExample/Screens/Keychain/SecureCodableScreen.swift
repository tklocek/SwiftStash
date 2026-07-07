//
//  SecureCodableScreen.swift
//  SwiftStashExample
//
// Copyright (c) 2026 SwiftStash contributors
// SPDX-License-Identifier: MIT
//

import SwiftUI
import SwiftStash

/// Any `Codable` value in the Keychain: `@SecureStash(codable:)` JSON-encodes the value
/// into the item's data, mirroring `@Stash(codable:)` on the UserDefaults side.
///
/// Note the `$credentials.exists` behaviour: it is a presence probe with **no decode** —
/// if the stored payload ever became undecodable (e.g. after a model change), `exists`
/// would still report `true` while reads return `nil`. That gap is your signal to
/// migrate or remove the stale item.
struct SecureCodableScreen: View {

    @SecureStash(codable: SharedKey.credentials) private var credentials: Credentials?

    @State private var username = ""
    @State private var password = ""
    @State private var stored: Credentials?
    @State private var exists = false

    var body: some View {
        Form {
            Section {
                LabeledContent("Username", value: stored?.username ?? "nil")
                LabeledContent("Password", value: stored == nil ? "nil" : "••••••••")
                LabeledContent("$credentials.exists", value: exists ? "true" : "false")
            } header: {
                Text("Stored credentials")
            }

            Section {
                TextField("Username", text: $username)
                SecureField("Password", text: $password)
                Button("Save") {
                    credentials = Credentials(username: username, password: password)
                    refresh()
                }
                .disabled(username.isEmpty || password.isEmpty)
                Button("Delete", role: .destructive) {
                    credentials = nil
                    refresh()
                }
            } footer: {
                Text("The whole struct is one keychain item — stored as JSON, decoded on read.")
            }
        }
        .navigationTitle("Codable secrets")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: refresh)
    }

    private func refresh() {
        stored = credentials
        exists = $credentials.exists
        username = stored?.username ?? ""
        password = stored?.password ?? ""
    }
}

#Preview {
    NavigationStack { SecureCodableScreen() }
}
