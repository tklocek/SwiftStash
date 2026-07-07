//
//  BiometricItemScreen.swift
//  SwiftStashExample
//
// Copyright (c) 2026 SwiftStash contributors
// SPDX-License-Identifier: MIT
//

import SwiftUI
import SwiftStash
import LocalAuthentication

/// A secret readable only after Face ID / Touch ID (or passcode), via
/// `KeychainManager.saveBiometric` / `.loadBiometric`.
///
/// The API shape to copy into your app:
/// - **Authentication is caller-owned**: you evaluate the `LAContext` yourself and pass
///   the satisfied context to `loadBiometric` — the package never prompts on its own.
/// - **There is no update for biometric items**: `saveBiometric` always deletes then
///   adds, because `SecItemUpdate` on an access-controlled item would force a re-prompt.
/// - `exists(for:with:)` probes presence **without** triggering a prompt (it uses an
///   `LAContext` with `interactionNotAllowed` under the hood).
///
/// Best experienced on a real device; the simulator supports enrolled Face ID
/// (Features → Face ID) for a full dry run.
struct BiometricItemScreen: View {

    private let keychain = KeychainManager(service: ExampleKeychain.service)
    private let key = "biometricSecret"

    @State private var draft = ""
    @State private var revealed: String?
    @State private var exists = false
    @State private var status = ""

    var body: some View {
        Form {
            Section {
                TextField("Secret to protect", text: $draft)
                Button("Save with user-presence protection") {
                    do {
                        try keychain.saveBiometric(
                            Data(draft.utf8),
                            for: key,
                            with: .genericPassword,
                            accessibility: .whenUnlockedThisDeviceOnly,
                            flags: [.userPresence]
                        )
                        status = "Saved. No prompt on save — only reads are gated."
                    } catch {
                        status = "Save failed: \(error.localizedDescription)"
                    }
                    refresh()
                }
                .disabled(draft.isEmpty)
            } header: {
                Text("Store")
            }

            Section {
                LabeledContent("exists (no prompt)", value: exists ? "true" : "false")
                Button("Reveal (prompts)") {
                    Task { await reveal() }
                }
                if let revealed {
                    LabeledContent("Secret", value: revealed)
                }
                Button("Delete", role: .destructive) {
                    do {
                        try keychain.delete(for: key, with: .genericPassword)
                        status = "Deleted."
                    } catch {
                        status = "Delete failed: \(error.localizedDescription)"
                    }
                    revealed = nil
                    refresh()
                }
            } header: {
                Text("Access")
            } footer: {
                Text("The exists probe never prompts, even though the item is access-controlled. Reveal evaluates the LAContext first, then passes the satisfied context to loadBiometric.")
            }

            if !status.isEmpty {
                Section("Last result") {
                    Text(status).font(.footnote)
                }
            }
        }
        .navigationTitle("Biometric item")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: refresh)
    }

    private func refresh() {
        exists = keychain.exists(for: key, with: .genericPassword)
    }

    private func reveal() async {
        let context = LAContext()
        do {
            // .deviceOwnerAuthentication allows passcode fallback, matching the
            // [.userPresence] flag the item was saved with.
            guard try await context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: "Reveal the protected demo secret"
            ) else {
                status = "Authentication was not granted."
                return
            }
            let data = try keychain.loadBiometric(for: key, with: .genericPassword, authenticationContext: context)
            revealed = String(data: data, encoding: .utf8) ?? "\(data.count) bytes"
            status = "Loaded with the satisfied context — no second prompt."
        } catch let error as KeychainError {
            status = "Load failed: \(error.localizedDescription)"
        } catch {
            status = "Authentication failed: \(error.localizedDescription)"
        }
    }
}

#Preview {
    NavigationStack { BiometricItemScreen() }
}
