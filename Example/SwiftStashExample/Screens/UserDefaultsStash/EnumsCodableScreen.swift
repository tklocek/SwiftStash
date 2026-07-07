//
//  EnumsCodableScreen.swift
//  SwiftStashExample
//
// Copyright (c) 2026 SwiftStash contributors
// SPDX-License-Identifier: MIT
//

import SwiftUI
import SwiftStashUI

/// The two non-primitive storage formats, side by side:
///
/// - **Enums** (`RawRepresentable` with a plist raw value) use the plain `key:`
///   initialiser and are stored as the raw value — `"dark"`, not JSON. That makes the
///   key fully interoperable with `@AppStorage` and with values written before adoption.
/// - **Any other Codable** uses the `codable:` label and is stored as JSON `Data`.
///
/// The label is the format contract: switching a key between `key:` and `codable:`
/// is a data-format change for anything already persisted under it — pick per key, once.
struct EnumsCodableScreen: View {

    @Stashed("formatTheme") private var theme: Theme = .system
    @Stashed(codable: "formatProfile") private var profile: UserProfile = .empty
    @Stashed(codable: "formatFavorite") private var favorite: UserProfile?

    var body: some View {
        Form {
            Section {
                Picker("Theme", selection: $theme) {
                    ForEach(Theme.allCases, id: \.self) { theme in
                        Text(theme.rawValue).tag(theme)
                    }
                }
                LabeledContent("Stored representation", value: storedThemeDescription)
            } header: {
                Text("Enum → raw value")
            } footer: {
                Text("The raw string is stored directly — @AppStorage reads this key unchanged.")
            }

            Section {
                TextField("Name", text: $profile.name)
                TextField("Email", text: $profile.email)
                LabeledContent("Stored representation", value: storedProfileDescription)
            } header: {
                Text("Codable → JSON Data")
            } footer: {
                Text("A failed encode logs the error and keeps the previously stored value — the key is never wiped by a bad write.")
            }

            Section {
                if let favorite {
                    LabeledContent("Favorite", value: favorite.name)
                    Button("Clear (removes the key)", role: .destructive) { self.favorite = nil }
                } else {
                    Button("Save current profile as favorite") { favorite = profile }
                }
            } header: {
                Text("Optional Codable")
            }
        }
        .navigationTitle("Enums & Codable")
        .navigationBarTitleDisplayMode(.inline)
    }

    /// Peek at the raw UserDefaults contents to show the actual stored format.
    private var storedThemeDescription: String {
        UserDefaults.standard.string(forKey: "formatTheme").map { "\"\($0)\"" } ?? "nothing stored"
    }

    private var storedProfileDescription: String {
        guard let data = UserDefaults.standard.data(forKey: "formatProfile") else { return "nothing stored" }
        return String(data: data, encoding: .utf8) ?? "\(data.count) bytes"
    }
}

#Preview {
    NavigationStack { EnumsCodableScreen() }
}
