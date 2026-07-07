//
//  InternetPasswordScreen.swift
//  SwiftStashExample
//
// Copyright (c) 2026 SwiftStash contributors
// SPDX-License-Identifier: MIT
//

import SwiftUI
import SwiftStash

/// Per-wrapper configuration: everything set globally in `configureKeychain` can be
/// overridden on a single property.
///
/// - `itemClass: .internetPassword(domain:)` stores the item as `kSecClassInternetPassword`
///   with the domain as its server attribute — the class used by password managers.
/// - `service:` namespaces password items. It is **not** a Keychain access group: a shared
///   service alone cannot share items between an app and its extension.
/// - `accessibility:` here beats the global `.whenUnlockedThisDeviceOnly` from launch.
struct InternetPasswordScreen: View {

    @SecureStash(
        key: "apiPassword",
        itemClass: .internetPassword(domain: "api.example.com")
    ) private var apiPassword: String?

    @SecureStash(
        key: "legacyToken",
        service: ExampleKeychain.legacyService,
        accessibility: .afterFirstUnlockThisDeviceOnly
    ) private var legacyToken: String?

    @State private var passwordDraft = ""
    @State private var storedPassword: String?
    @State private var storedLegacyToken: String?

    var body: some View {
        Form {
            Section {
                LabeledContent("Stored", value: storedPassword ?? "nil")
                TextField("Password for api.example.com", text: $passwordDraft)
                Button("Save") {
                    apiPassword = passwordDraft
                    refresh()
                }
                Button("Delete", role: .destructive) {
                    apiPassword = nil
                    refresh()
                }
            } header: {
                Text("itemClass: .internetPassword")
            } footer: {
                Text("Stored as kSecClassInternetPassword for domain api.example.com. Note it does not appear in the allKeys list on the Helpers screen unless queried with the matching item class.")
            }

            Section {
                LabeledContent("Stored", value: storedLegacyToken ?? "nil")
                Button("Save token in legacy service") {
                    legacyToken = "legacy-\(Int.random(in: 100...999))"
                    refresh()
                }
                Button("Delete", role: .destructive) {
                    legacyToken = nil
                    refresh()
                }
            } header: {
                Text("service & accessibility overrides")
            } footer: {
                Text("This item lives under \(ExampleKeychain.legacyService) with .afterFirstUnlockThisDeviceOnly — readable in the background after the first unlock, unlike the global default.")
            }
        }
        .navigationTitle("Item class & overrides")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: refresh)
    }

    private func refresh() {
        storedPassword = apiPassword
        storedLegacyToken = legacyToken
        passwordDraft = apiPassword ?? ""
    }
}

#Preview {
    NavigationStack { InternetPasswordScreen() }
}
