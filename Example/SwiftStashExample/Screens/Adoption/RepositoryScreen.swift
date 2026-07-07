//
//  RepositoryScreen.swift
//  SwiftStashExample
//
// Copyright (c) 2026 SwiftStash contributors
// SPDX-License-Identifier: MIT
//

import SwiftUI
import SwiftStash

/// Clean-architecture style: the rest of the app depends on a protocol, and SwiftStash
/// only appears inside one concrete implementation.
///
/// Tests inject `InMemorySettingsRepository` — no UserDefaults, no Keychain, no mocking
/// framework. The live implementation is nothing but wrappers; there is no extra
/// persistence code to test.
protocol SettingsRepository {
    var username: String { get nonmutating set }
    var authToken: String? { get nonmutating set }
}

/// Production implementation — each protocol requirement is a wrapper, nothing else.
struct StashSettingsRepository: SettingsRepository {
    @Stash(SharedKey.username) var username = ""
    @SecureStash(key: SharedKey.authToken) var authToken: String?
}

/// Test/preview double. `nonmutating set` in the protocol lets a struct-based fake use
/// reference storage, mirroring the wrappers' semantics.
struct InMemorySettingsRepository: SettingsRepository {
    private final class Box { var username = ""; var authToken: String? }
    private let box = Box()

    var username: String {
        get { box.username }
        nonmutating set { box.username = newValue }
    }
    var authToken: String? {
        get { box.authToken }
        nonmutating set { box.authToken = newValue }
    }
}

struct RepositoryScreen: View {

    /// Swap in `InMemorySettingsRepository()` to run this screen against pure memory.
    private let repository: SettingsRepository = StashSettingsRepository()

    @State private var username = ""
    @State private var token = ""

    var body: some View {
        Form {
            Section {
                TextField("Username", text: $username)
                TextField("Auth token", text: $token)
                Button("Save") {
                    repository.username = username
                    repository.authToken = token.isEmpty ? nil : token
                }
            } footer: {
                Text("The view only knows the SettingsRepository protocol. The live implementation is two property-wrapper lines; the in-memory fake used by tests is in this same file.")
            }
        }
        .navigationTitle("Repository")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            username = repository.username
            token = repository.authToken ?? ""
        }
    }
}

#Preview {
    NavigationStack { RepositoryScreen() }
}
