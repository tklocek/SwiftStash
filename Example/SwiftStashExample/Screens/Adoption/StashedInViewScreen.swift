//
//  StashedInViewScreen.swift
//  SwiftStashExample
//
// Copyright (c) 2026 SwiftStash contributors
// SPDX-License-Identifier: MIT
//

import SwiftUI
import SwiftStashUI

/// `@Stashed` is the drop-in `@AppStorage` replacement: a SwiftUI `DynamicProperty`
/// whose projected value is a `Binding`, so it plugs straight into `TextField`,
/// `Picker`, `Stepper`, and friends.
///
/// What `@AppStorage` cannot do, demonstrated below:
/// - store a `Codable` value (`profile`) with the same syntax,
/// - re-render when the key is written from *anywhere* — another `@Stashed`,
///   a `@Stash` in a view model, `@AppStorage`, or raw `UserDefaults.set`.
///
/// Storage representation is identical to `@AppStorage`, so adopting this wrapper
/// in an existing app preserves every previously persisted value.
struct StashedInViewScreen: View {

    @Stashed(SharedKey.username) private var username = ""
    @Stashed(SharedKey.launchCount) private var launchCount = 0
    @Stashed(SharedKey.theme) private var theme: Theme = .system
    @Stashed(codable: SharedKey.profile) private var profile: UserProfile = .empty

    var body: some View {
        Form {
            Section {
                TextField("Username", text: $username)
                Stepper("Launch count: \(launchCount)", value: $launchCount)
                Picker("Theme", selection: $theme) {
                    ForEach(Theme.allCases, id: \.self) { theme in
                        Text(theme.rawValue).tag(theme)
                    }
                }
            } header: {
                Text("Primitives & enum")
            } footer: {
                Text("Two-way bindings via the projected value, exactly like @AppStorage. The enum is stored as its raw value.")
            }

            Section {
                TextField("Name", text: $profile.name)
                TextField("Email", text: $profile.email)
                Stepper("Age: \(profile.age)", value: $profile.age, in: 0...120)
            } header: {
                Text("Codable value")
            } footer: {
                Text("One JSON blob under a single key — @AppStorage has no equivalent. The Binding supports key-path member access ($profile.name).")
            }
        }
        .navigationTitle("@Stashed")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack { StashedInViewScreen() }
}
