//
//  KeychainHelpersScreen.swift
//  SwiftStashExample
//
// Copyright (c) 2026 SwiftStash contributors
// SPDX-License-Identifier: MIT
//

import SwiftUI
import SwiftStash

/// Batch and introspection helpers — the maintenance surface behind `@SecureStash`:
///
/// - `SecureStashHelpers.allKeys(service:)` lists every stored key for a service,
/// - `SecureStashHelpers.exists(key:service:)` probes one key without a wrapper,
/// - `SecureStashHelpers.clearAll(service:)` deletes everything for a service and
///   returns the count — the "log out / wipe" primitive.
///
/// All three are synchronous and support password item classes only. Lookups match
/// items regardless of their synchronizable state.
struct KeychainHelpersScreen: View {

    @State private var mainKeys: [String] = []
    @State private var legacyKeys: [String] = []
    @State private var internetKeys: [String] = []
    @State private var lastClearCount: Int?
    @State private var confirmClear = false

    var body: some View {
        Form {
            Section("allKeys · \(ExampleKeychain.service)") {
                keyList(mainKeys)
            }

            Section {
                keyList(internetKeys)
            } header: {
                Text("allKeys · .internetPassword")
            } footer: {
                Text("The same service, queried with itemClass: .internetPassword — item classes are separate namespaces.")
            }

            Section {
                keyList(legacyKeys)
            } header: {
                Text("allKeys · \(ExampleKeychain.legacyService)")
            } footer: {
                Text("Items created with the per-wrapper service override live here, invisible to the main service.")
            }

            Section {
                LabeledContent("exists(key: \"\(SharedKey.authToken.rawValue)\")",
                               value: SecureStashHelpers.exists(key: SharedKey.authToken.rawValue, service: ExampleKeychain.service) ? "true" : "false")
                Button("Refresh") { refresh() }
                Button("Clear all in \(ExampleKeychain.service)", role: .destructive) {
                    confirmClear = true
                }
                if let lastClearCount {
                    LabeledContent("Last clearAll deleted", value: "\(lastClearCount) item(s)")
                }
            } footer: {
                Text("clearAll is the app's logout/wipe primitive — populate items on the other Keychain screens, then clear them here in one call.")
            }
        }
        .navigationTitle("Helpers")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: refresh)
        .confirmationDialog(
            "Delete every generic-password item stored under \(ExampleKeychain.service)?",
            isPresented: $confirmClear,
            titleVisibility: .visible
        ) {
            Button("Delete all", role: .destructive) {
                lastClearCount = SecureStashHelpers.clearAll(service: ExampleKeychain.service)
                refresh()
            }
        }
    }

    @ViewBuilder
    private func keyList(_ keys: [String]) -> some View {
        if keys.isEmpty {
            Text("No items").foregroundStyle(.secondary)
        } else {
            ForEach(keys, id: \.self) { key in
                Text(key).font(.footnote.monospaced())
            }
        }
    }

    private func refresh() {
        mainKeys = SecureStashHelpers.allKeys(service: ExampleKeychain.service).sorted()
        legacyKeys = SecureStashHelpers.allKeys(service: ExampleKeychain.legacyService).sorted()
        internetKeys = SecureStashHelpers.allKeys(
            service: ExampleKeychain.service,
            itemClass: .internetPassword(domain: "api.example.com")
        ).sorted()
    }
}

#Preview {
    NavigationStack { KeychainHelpersScreen() }
}
