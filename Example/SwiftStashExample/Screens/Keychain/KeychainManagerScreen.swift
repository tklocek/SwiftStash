//
//  KeychainManagerScreen.swift
//  SwiftStashExample
//
// Copyright (c) 2026 SwiftStash contributors
// SPDX-License-Identifier: MIT
//

import SwiftUI
import SwiftStash

/// The lower-level instance API for callers that need **error handling** instead of the
/// wrapper's log-and-return-nil semantics: every method throws a typed `KeychainError`.
///
/// Semantics worth testing by hand here:
/// - `save` does **not** overwrite — a second save of the same key throws `.duplicateItem`
///   (the wrappers fall back to update automatically; this API makes the choice yours),
/// - `update` requires the item to exist (`.itemNotFound` otherwise),
/// - `load` of a missing key throws `.itemNotFound` rather than returning nil.
struct KeychainManagerScreen: View {

    private let keychain = KeychainManager(service: ExampleKeychain.service)
    private let key = "managedToken"

    @State private var log: [String] = []

    var body: some View {
        Form {
            Section {
                Button("save") {
                    perform("save") {
                        try keychain.save(Data("token-\(Int.random(in: 100...999))".utf8), for: key, with: .genericPassword)
                        return "saved"
                    }
                }
                Button("save again (expect duplicateItem)") {
                    perform("save") {
                        try keychain.save(Data("other".utf8), for: key, with: .genericPassword)
                        return "saved — no duplicate existed"
                    }
                }
                Button("load") {
                    perform("load") {
                        let data = try keychain.load(for: key, with: .genericPassword)
                        return String(data: data, encoding: .utf8) ?? "\(data.count) bytes"
                    }
                }
                Button("update") {
                    perform("update") {
                        try keychain.update(Data("updated-\(Int.random(in: 100...999))".utf8), for: key, with: .genericPassword)
                        return "updated"
                    }
                }
                Button("delete", role: .destructive) {
                    perform("delete") {
                        try keychain.delete(for: key, with: .genericPassword)
                        return "deleted"
                    }
                }
            } header: {
                Text("CRUD · key \"\(key)\"")
            } footer: {
                Text("Run the calls out of order on purpose — load before save, update after delete — to see each typed KeychainError surface.")
            }

            Section("Log") {
                if log.isEmpty {
                    Text("No calls yet").foregroundStyle(.secondary)
                } else {
                    ForEach(Array(log.enumerated()), id: \.offset) { _, line in
                        Text(line).font(.footnote.monospaced())
                    }
                }
            }
        }
        .navigationTitle("KeychainManager")
        .navigationBarTitleDisplayMode(.inline)
    }

    /// Runs one keychain call and records either its result or the error. Every
    /// `KeychainManager` method declares `throws(KeychainError)`, so a direct
    /// `do { try keychain.load(…) } catch { … }` binds `error` as `KeychainError` —
    /// no existential casting. (The parameter here stays untyped only because closure
    /// literals do not yet infer typed throws from context.)
    private func perform(_ name: String, _ operation: () throws -> String) {
        do {
            let outcome = try operation()
            log.insert("\(name) ✓ \(outcome)", at: 0)
        } catch {
            log.insert("\(name) ✗ \(error.localizedDescription)", at: 0)
        }
    }
}

#Preview {
    NavigationStack { KeychainManagerScreen() }
}
