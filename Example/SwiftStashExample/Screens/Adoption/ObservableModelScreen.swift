//
//  ObservableModelScreen.swift
//  SwiftStashExample
//
// Copyright (c) 2026 SwiftStash contributors
// SPDX-License-Identifier: MIT
//

import SwiftUI
import SwiftStash

/// Modern observation: an `@Observable` model backed by SwiftStash.
///
/// The `@Observable` macro does not accept property wrappers on stored properties,
/// so the wrappers live in a small private persistence type and the model copies
/// values in and out. The macro tracks the plain stored properties as usual.
@Observable @MainActor
final class ProfileModel {

    var profile: UserProfile
    var credentials: Credentials?

    /// Wrappers can't sit directly in an @Observable class — group them here instead.
    private struct Persistence {
        @Stash(codable: SharedKey.profile) var profile: UserProfile = .empty
        @SecureStash(codable: SharedKey.credentials) var credentials: Credentials?
    }

    private let persistence = Persistence()

    init() {
        profile = persistence.profile
        credentials = persistence.credentials
    }

    func save() {
        persistence.profile = profile
        persistence.credentials = credentials
    }

    func reload() {
        profile = persistence.profile
        credentials = persistence.credentials
    }
}

struct ObservableModelScreen: View {

    @State private var model = ProfileModel()

    var body: some View {
        Form {
            Section {
                TextField("Name", text: $model.profile.name)
                TextField("Email", text: $model.profile.email)
            } header: {
                Text("Profile · UserDefaults (Codable)")
            }

            Section {
                if model.credentials != nil {
                    LabeledContent("Username", value: model.credentials?.username ?? "")
                    Button("Forget credentials", role: .destructive) {
                        model.credentials = nil
                        model.save()
                    }
                } else {
                    Button("Store sample credentials") {
                        model.credentials = .sample
                        model.save()
                    }
                }
            } header: {
                Text("Credentials · Keychain (Codable)")
            } footer: {
                Text("Setting credentials to nil deletes the Keychain item.")
            }

            Section {
                Button("Save") { model.save() }
                Button("Reload") { model.reload() }
            }
        }
        .navigationTitle("@Observable")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack { ObservableModelScreen() }
}
