//
//  ObservableObjectScreen.swift
//  SwiftStashExample
//
// Copyright (c) 2026 SwiftStash contributors
// SPDX-License-Identifier: MIT
//

import SwiftUI
import SwiftStash

/// Classic MVVM: the view model owns `@Stash`/`@SecureStash` wrappers and republishes
/// their values through `@Published` properties.
///
/// This is the pattern for existing `ObservableObject` codebases: persistence stays in
/// the view model (no SwiftUI import needed for it — `@Stash` is pure Foundation), and
/// the view keeps binding to `@Published` exactly as before.
@MainActor
final class SettingsViewModel: ObservableObject {

    @Published var username: String
    @Published var theme: Theme
    @Published var authToken: String

    // Persistence — wrappers are cheap value types; hold them for the object's lifetime.
    @Stash(SharedKey.username) private var storedUsername = ""
    @Stash(SharedKey.theme) private var storedTheme: Theme = .system
    @SecureStash(key: SharedKey.authToken) private var storedAuthToken: String?

    init() {
        username = ""
        theme = .system
        authToken = ""
        reload()
    }

    /// Re-reads every persisted value into the published properties.
    func reload() {
        username = storedUsername
        theme = storedTheme
        authToken = storedAuthToken ?? ""
    }

    /// Persists the published properties. An empty token deletes the Keychain item —
    /// assigning nil to a @SecureStash removes it.
    func save() {
        storedUsername = username
        storedTheme = theme
        storedAuthToken = authToken.isEmpty ? nil : authToken
    }
}

struct ObservableObjectScreen: View {

    @StateObject private var model = SettingsViewModel()

    var body: some View {
        Form {
            Section {
                TextField("Username", text: $model.username)
                Picker("Theme", selection: $model.theme) {
                    ForEach(Theme.allCases, id: \.self) { theme in
                        Text(theme.rawValue).tag(theme)
                    }
                }
                TextField("Auth token (Keychain)", text: $model.authToken)
            } footer: {
                Text("UserDefaults and Keychain behind one view model. Leaving the token empty deletes the Keychain item on Save.")
            }

            Section {
                Button("Save") { model.save() }
                Button("Reload") { model.reload() }
            }
        }
        .navigationTitle("ObservableObject")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack { ObservableObjectScreen() }
}
