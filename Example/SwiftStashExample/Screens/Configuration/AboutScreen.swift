//
//  AboutScreen.swift
//  SwiftStashExample
//
// Copyright (c) 2026 SwiftStash contributors
// SPDX-License-Identifier: MIT
//

import SwiftUI

/// Why this package exists: the seven `@AppStorage` limitations SwiftStash removes,
/// each mapped to the screen that demonstrates it.
struct AboutScreen: View {

    private let limitations: [(String, String)] = [
        ("SwiftUI-only", "@Stash is pure Foundation — see the view-model and repository screens."),
        ("No Codable", "@Stash(codable:)/@SecureStash(codable:) — Enums & Codable, Codable secrets."),
        ("No secure storage", "@SecureStash is the same property syntax backed by the Keychain."),
        ("No static state under Swift 6", "Sendable wrappers with nonmutating set — Static shared state."),
        ("No observation outside its view", "Per-key AsyncStream updates — the Observation section."),
        ("Runtime crashes on wrong types", "Non-plist misuse is a compile error (UserDefaultsPrimitiveType)."),
        ("Can't tell \"never set\" from \"default\"", "$property.exists — Optionals & the $handle."),
    ]

    var body: some View {
        Form {
            Section {
                Text("SwiftStash removes seven hard limitations of @AppStorage at zero switching cost: the storage representation is identical, so existing values are read as-is and an app can migrate one property at a time.")
                    .font(.subheadline)
            } header: {
                Text("Why not just @AppStorage?")
            }

            Section {
                ForEach(limitations, id: \.0) { limitation, remedy in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(limitation).font(.subheadline.weight(.semibold))
                        Text(remedy).font(.caption).foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 2)
                }
            } header: {
                Text("The seven limitations")
            } footer: {
                Text("If none of these apply to your app, @AppStorage is fine. If any does, the adoption playbook in AGENTS.md walks through the migration.")
            }

            Section("Package") {
                LabeledContent("Modules", value: "SwiftStash · SwiftStashUI")
                LabeledContent("Swift", value: "6, strict concurrency")
                LabeledContent("Dependencies", value: "none")
            }
        }
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack { AboutScreen() }
}
