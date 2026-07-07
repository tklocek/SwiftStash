//
//  KeychainCryptoManagerProtocol.swift
//  SwiftStash
//
// Copyright (c) 2026 SwiftStash contributors
// SPDX-License-Identifier: MIT
//

#if canImport(LocalAuthentication)

import Foundation
import LocalAuthentication
import Security

extension KeychainManager: KeychainCryptoManagerProtocol {}

/// A protocol covering the higher-level Secure Enclave / biometric / cryptographic
/// keychain operations that go beyond the plain CRUD API exposed by
/// ``KeychainManagerProtocol``.
///
/// This is intentionally a **separate** protocol so existing mocks of
/// ``KeychainManagerProtocol`` are not forced to implement crypto methods.
/// ``KeychainManager`` conforms to both.
///
/// Authentication is always **caller-owned**: methods accept an optional,
/// already-evaluated `LAContext` and never create prompts of their own (except
/// the Security framework's implicit prompt when a protected item is actually
/// used). This mirrors the shape of the underlying `SecItem`/`SecKey` APIs.
///
/// > Note: These APIs require the LocalAuthentication framework and are
/// > therefore unavailable on tvOS.
public protocol KeychainCryptoManagerProtocol: Sendable {

    // MARK: - Existence probes (no prompt)

    /// Probes existence of a generic-/internet-password item without surfacing
    /// biometric prompts.
    ///
    /// For biometric items (items written with `kSecAttrAccessControl`),
    /// `SecItemCopyMatching` would normally trigger a Face ID / Touch ID prompt
    /// even when only checking for existence. To avoid that, this method uses
    /// an `LAContext` with `interactionNotAllowed = true`. If
    /// `authenticationContext` is `nil`, a throwaway `LAContext` is created
    /// for the probe.
    ///
    /// When a biometric item exists but cannot be returned without interaction,
    /// `SecItemCopyMatching` returns `errSecInteractionNotAllowed`. That status
    /// is treated as "exists" here.
    ///
    /// ```swift
    /// if keychain.exists(for: "auth_token", with: .genericPassword) { /* ... */ }
    /// ```
    ///
    /// - Parameters:
    ///   - key: The key associated with the item (`kSecAttrAccount` for
    ///     `.genericPassword` / `.internetPassword`).
    ///   - type: The Keychain item class.
    ///   - authenticationContext: Optional pre-built context. When `nil`, the
    ///     implementation creates an internal throwaway context.
    /// - Returns: `true` if an item is found, including the
    ///   `errSecInteractionNotAllowed` case.
    func exists(
        for key: String,
        with type: KeychainItemClass,
        authenticationContext: LAContext?
    ) -> Bool

    /// Probes existence of a cryptographic key by its application tag.
    /// Algorithm-agnostic when `descriptor.algorithm == nil`.
    ///
    /// This call is idempotent and **never** triggers a biometric prompt — it
    /// returns the key reference, not the underlying key material.
    ///
    /// ```swift
    /// let probe = CryptoKeyDescriptor(stringTag: "com.example.binding.user42")
    /// if keychain.existsKey(probe) { /* ... */ }
    /// ```
    ///
    /// - Parameter descriptor: Identifies the key by application tag + (optional)
    ///   algorithm.
    /// - Returns: `true` if a matching key is present, `false` otherwise.
    func existsKey(_ descriptor: CryptoKeyDescriptor) -> Bool

    // MARK: - Biometric password items

    /// Reads a biometric-protected `Data` item.
    ///
    /// The supplied `LAContext` MUST already be satisfied (typically via
    /// `LAContext.evaluatePolicy(...)` performed by the caller) so the
    /// Security framework can decrypt the item without prompting again.
    ///
    /// ```swift
    /// let context = LAContext()
    /// try await context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics,
    ///                                  localizedReason: "Unlock")
    /// let data = try keychain.loadBiometric(
    ///     for: "auth_token",
    ///     with: .genericPassword,
    ///     authenticationContext: context
    /// )
    /// ```
    ///
    /// - Parameters:
    ///   - key: The key associated with the item.
    ///   - type: The Keychain item class.
    ///   - authenticationContext: An already-satisfied `LAContext`.
    /// - Returns: The stored `Data`.
    /// - Throws: ``KeychainError/itemNotFound`` if no item exists.
    ///           Other ``KeychainError`` cases for Security framework failures.
    func loadBiometric(
        for key: String,
        with type: KeychainItemClass,
        authenticationContext: LAContext
    ) throws(KeychainError) -> Data

    /// Writes a biometric-protected `Data` item using the **delete-then-add**
    /// pattern.
    ///
    /// `SecItemUpdate` on a biometric item causes a re-prompt and is therefore
    /// forbidden — the package enforces the correct pattern so callers cannot
    /// get this wrong. `kSecAttrAccessControl` is built from
    /// (`accessibility`, `flags`); `kSecAttrSynchronizable` is forced to `false`.
    ///
    /// ```swift
    /// try keychain.saveBiometric(
    ///     Data("secret".utf8),
    ///     for: "auth_token",
    ///     with: .genericPassword,
    ///     accessibility: .whenUnlockedThisDeviceOnly,
    ///     flags: [.userPresence]
    /// )
    /// ```
    ///
    /// - Parameters:
    ///   - value: The `Data` to store.
    ///   - key: The key associated with the item.
    ///   - type: The Keychain item class.
    ///   - accessibility: The `kSecAttrAccessible` value baked into the
    ///     access control object.
    ///   - flags: Additional user-presence / biometry constraints.
    /// - Throws: ``KeychainError/accessControlCreationFailed`` if the access
    ///           control could not be built. Other ``KeychainError`` cases on
    ///           Security framework failures.
    func saveBiometric(
        _ value: Data,
        for key: String,
        with type: KeychainItemClass,
        accessibility: KeychainAccessibility,
        flags: SecAccessControlFlags
    ) throws(KeychainError)

    // MARK: - Cryptographic keys

    /// Returns a `SecKey` reference to the private key identified by the
    /// descriptor. The caller may pass the returned key into
    /// `SecKeyCreateSignature` or `SecKeyCopyPublicKey`.
    ///
    /// Loading the key reference normally does not authenticate by itself.
    /// Protected private-key operations, such as creating a signature with a
    /// Secure Enclave key guarded by user-presence flags, may require device-owner
    /// authentication when the key is used. If the caller has already satisfied
    /// an `LAContext`, pass it here so the Security framework can reuse the same
    /// device-owner confirmation.
    ///
    /// - Note: For Secure Enclave keys, the returned `SecKey` is an opaque
    ///   reference — the underlying key material never leaves the enclave.
    ///
    /// ```swift
    /// let descriptor = CryptoKeyDescriptor(stringTag: tag, algorithm: .ec)
    /// let key = try keychain.loadKeyReference(descriptor)
    /// ```
    ///
    /// - Parameters:
    ///   - descriptor: Identifies the key by application tag and algorithm.
    ///     `algorithm` should not be `nil` for this call.
    ///   - authenticationContext: An optional caller-owned `LAContext`.
    /// - Returns: A `SecKey` reference to the private key.
    /// - Throws: ``KeychainError/itemNotFound`` if no matching key exists.
    func loadKeyReference(
        _ descriptor: CryptoKeyDescriptor,
        authenticationContext: LAContext?
    ) throws(KeychainError) -> SecKey

    /// Generates an asymmetric key pair and returns the public `SecKey`.
    ///
    /// The private key is stored according to `storage`:
    /// - `.secureEnclave(...)`: private key never leaves Secure Enclave hardware.
    ///   Only `.ec` is supported by the enclave.
    /// - `.keychain(...)`: private key lives in the keychain, protected by
    ///   `kSecAttrAccessible`.
    ///
    /// If the caller has already satisfied an `LAContext`, pass it so key
    /// generation can use the same explicit device-owner confirmation. This
    /// method does not create or evaluate an `LAContext`; the caller owns
    /// authentication.
    ///
    /// - Note: Replacement behavior: if any key already exists under
    ///   `descriptor.tag`, regardless of algorithm, it is deleted first and a
    ///   fresh key pair is generated.
    ///
    /// ```swift
    /// let publicKey = try keychain.generateKey(
    ///     descriptor: CryptoKeyDescriptor(stringTag: "com.example.binding.user42", algorithm: .ec),
    ///     keySizeInBits: 256,
    ///     storage: .secureEnclave(
    ///         accessibility: .whenUnlockedThisDeviceOnly,
    ///         flags: [.privateKeyUsage]
    ///     )
    /// )
    /// ```
    ///
    /// - Parameters:
    ///   - descriptor: Identifies the key by application tag + (optional)
    ///     algorithm.
    ///   - keySizeInBits: Key length. Typical values: `256` (EC P-256),
    ///     `4096` (RSA-4096).
    ///   - storage: Where the private key lives and how it's protected.
    ///   - authenticationContext: An optional caller-owned `LAContext`.
    /// - Returns: The public `SecKey`.
    /// - Throws: ``KeychainError/secureEnclaveAlgorithmInvalid`` if `storage`
    ///           is Secure Enclave but the algorithm is not `.ec`.
    ///           ``KeychainError/keyGenerationFailed(_:)`` on Security
    ///           framework failure.
    ///           ``KeychainError/publicKeyExtractionFailed`` if the public half
    ///           cannot be extracted.
    func generateKey(
        descriptor: CryptoKeyDescriptor,
        keySizeInBits: Int,
        storage: CryptoKeyStorage,
        authenticationContext: LAContext?
    ) throws(KeychainError) -> SecKey

    /// Deletes the key under `descriptor.tag`. Idempotent —
    /// `errSecItemNotFound` is treated as success. If
    /// `descriptor.algorithm == nil`, deletes keys of any algorithm under
    /// that tag.
    ///
    /// - Parameter descriptor: Identifies the key by application tag +
    ///   (optional) algorithm.
    /// - Throws: ``KeychainError`` on Security framework failures other than
    ///           `errSecItemNotFound`.
    func deleteKey(_ descriptor: CryptoKeyDescriptor) throws(KeychainError)
}

#endif
