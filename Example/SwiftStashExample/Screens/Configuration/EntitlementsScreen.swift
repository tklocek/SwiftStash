//
//  EntitlementsScreen.swift
//  SwiftStashExample
//
// Copyright (c) 2026 SwiftStash contributors
// SPDX-License-Identifier: MIT
//

import SwiftUI

/// The two SwiftStash features that need app entitlements — shown as reference code
/// instead of live demos, because this sample project deliberately builds without code
/// signing or a development team.
///
/// Copy the snippets into an app that has the matching capability enabled.
struct EntitlementsScreen: View {

    var body: some View {
        Form {
            Section {
                Text("""
                // 1. Add the App Groups capability to the app \
                and every extension that shares the data.
                // 2. Route @Stash/@Stashed at the shared suite once, at launch:
                SwiftStash.configureUserDefaults(
                    suiteName: "group.com.example.app"
                )
                """)
                .font(.footnote.monospaced())
            } header: {
                Text("App Groups · shared UserDefaults")
            } footer: {
                Text("After this one call, every wrapper without an explicit userDefaults:/store: override reads and writes the shared suite — settings become visible to widgets and extensions with no per-property changes.")
            }

            Section {
                Text("""
                // Requires iCloud Keychain on the device; \
                no extra entitlement, but the item must
                // use a syncable accessibility — \
                *ThisDeviceOnly cannot sync (asserts in debug):
                @SecureStash(
                    key: "sharedToken",
                    accessibility: .afterFirstUnlock,
                    isSynchronizable: true
                )
                var sharedToken: String?
                """)
                .font(.footnote.monospaced())
            } header: {
                Text("iCloud Keychain sync")
            } footer: {
                Text("isSynchronizable: true with any *ThisDeviceOnly accessibility is invalid — iCloud cannot sync device-only items. SwiftStash asserts in debug builds; in release the write fails at the SecItem layer. Lookups match items in any synchronizable state, so reads keep working either way.")
            }

            Section {
                Text("Keychain sharing between an app and its extensions needs a Keychain access group, which the package does not currently expose — the service: parameter namespaces items but is not an access group.")
                    .font(.footnote)
            } header: {
                Text("Known limit")
            }
        }
        .navigationTitle("App Groups & iCloud")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack { EntitlementsScreen() }
}
