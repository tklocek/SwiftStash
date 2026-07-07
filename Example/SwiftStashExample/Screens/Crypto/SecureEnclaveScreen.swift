//
//  SecureEnclaveScreen.swift
//  SwiftStashExample
//
// Copyright (c) 2026 SwiftStash contributors
// SPDX-License-Identifier: MIT
//

import SwiftUI
import SwiftStash
import Security

/// Hardware-backed key pairs: `generateKey`, `existsKey`, `loadKeyReference`,
/// `deleteKey`, driven by a `CryptoKeyDescriptor` (application tag + algorithm).
///
/// The storage picker covers both `CryptoKeyStorage` cases:
/// - `.secureEnclave` — EC P-256 only, real hardware only (the simulator throws
///   `keyGenerationFailed`, shown below instead of hidden). The private key never
///   leaves the enclave; `loadKeyReference` returns an opaque reference.
/// - `.keychain` — software key protected by `kSecAttrAccessible`; works everywhere,
///   so this screen is fully testable in the simulator too.
///
/// Signing demonstrates the prompt timing rule: user-presence flags are enforced when
/// the `SecKey` is **used** (`SecKeyCreateSignature`), not when it is loaded.
struct SecureEnclaveScreen: View {

    private enum StorageChoice: String, CaseIterable {
        case secureEnclave = "Secure Enclave"
        case software = "Keychain (software)"
    }

    private let keychain = KeychainManager(service: ExampleKeychain.service)
    private let descriptor = CryptoKeyDescriptor(stringTag: "com.swiftstash.example.demokey", algorithm: .ec)

    @State private var storageChoice = StorageChoice.secureEnclave
    @State private var requireUserPresence = false
    @State private var keyExists = false
    @State private var status = ""

    var body: some View {
        Form {
            Section {
                Picker("Private key storage", selection: $storageChoice) {
                    ForEach(StorageChoice.allCases, id: \.self) { choice in
                        Text(choice.rawValue).tag(choice)
                    }
                }
                if storageChoice == .secureEnclave {
                    Toggle("Require user presence to sign", isOn: $requireUserPresence)
                }
                Button("Generate EC P-256 key pair") { generate() }
            } header: {
                Text("Generate")
            } footer: {
                Text("generateKey replaces any existing key under the same tag and returns the public key. Secure Enclave requires a real device.")
            }

            Section {
                LabeledContent("existsKey (no prompt)", value: keyExists ? "true" : "false")
                Button("Sign a message") { sign() }
                Button("Delete key (idempotent)", role: .destructive) { deleteKey() }
            } header: {
                Text("Use")
            } footer: {
                Text("With user presence enabled, the prompt appears at SecKeyCreateSignature — not at loadKeyReference. Delete never fails on a missing key.")
            }

            Section {
                Button("Try RSA in the Secure Enclave") {
                    do {
                        _ = try keychain.generateKey(
                            descriptor: CryptoKeyDescriptor(stringTag: "com.swiftstash.example.rsa", algorithm: .rsa),
                            keySizeInBits: 2048,
                            storage: .secureEnclave(accessibility: .whenUnlockedThisDeviceOnly, flags: [.privateKeyUsage])
                        )
                        status = "Unexpected success"
                    } catch {
                        // Validated before any SecItem call — same error on any device.
                        status = "Rejected as expected: \(error.localizedDescription)"
                    }
                }
            } header: {
                Text("Validation")
            } footer: {
                Text("The enclave only supports EC P-256; RSA is rejected with secureEnclaveAlgorithmInvalid before touching the keychain.")
            }

            if !status.isEmpty {
                Section("Last result") {
                    Text(status).font(.footnote)
                }
            }
        }
        .navigationTitle("Secure Enclave key")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: refresh)
    }

    private var storage: CryptoKeyStorage {
        switch storageChoice {
        case .secureEnclave:
            var flags: SecAccessControlFlags = [.privateKeyUsage]
            if requireUserPresence { flags.insert(.userPresence) }
            return .secureEnclave(accessibility: .whenUnlockedThisDeviceOnly, flags: flags)
        case .software:
            return .keychain(accessibility: .whenUnlockedThisDeviceOnly)
        }
    }

    private func refresh() {
        keyExists = keychain.existsKey(descriptor)
    }

    private func generate() {
        do {
            let publicKey = try keychain.generateKey(
                descriptor: descriptor,
                keySizeInBits: 256,
                storage: storage
            )
            status = "Public key: \(publicKeySummary(publicKey))"
        } catch {
            status = "Generation failed: \(error.localizedDescription)"
        }
        refresh()
    }

    private func sign() {
        do {
            let privateKey = try keychain.loadKeyReference(descriptor)
            let message = Data("Signed by SwiftStash example".utf8)
            var error: Unmanaged<CFError>?
            guard let signature = SecKeyCreateSignature(
                privateKey,
                .ecdsaSignatureMessageX962SHA256,
                message as CFData,
                &error
            ) as Data? else {
                let reason = error?.takeRetainedValue().localizedDescription ?? "unknown error"
                status = "Signing failed: \(reason)"
                return
            }
            status = "Signature (\(signature.count) bytes): \(signature.prefix(12).base64EncodedString())…"
        } catch {
            status = "Signing failed: \(error.localizedDescription)"
        }
    }

    private func deleteKey() {
        do {
            try keychain.deleteKey(descriptor)
            status = "Deleted (or was already absent)."
        } catch {
            status = "Delete failed: \(error.localizedDescription)"
        }
        refresh()
    }

    private func publicKeySummary(_ key: SecKey) -> String {
        var error: Unmanaged<CFError>?
        guard let data = SecKeyCopyExternalRepresentation(key, &error) as Data? else {
            return "opaque reference"
        }
        return "\(data.count) bytes · \(data.prefix(8).base64EncodedString())…"
    }
}

#Preview {
    NavigationStack { SecureEnclaveScreen() }
}
