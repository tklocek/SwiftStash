//
//  CryptoKeyStorage.swift
//  SwiftStash
//
// Copyright (c) 2026 SwiftStash contributors
// SPDX-License-Identifier: MIT
//

import Foundation

/// Describes where the private half of a cryptographic key pair lives and how
/// it is protected.
///
/// Two distinct storage strategies are supported:
///
/// - ``secureEnclave(accessibility:flags:)`` — the private key is generated and
///   kept inside Secure Enclave hardware. Only `CryptoKeyAlgorithm.ec` is supported.
///   Protection is via `kSecAttrTokenID = kSecAttrTokenIDSecureEnclave` combined
///   with `kSecAttrAccessControl` (built from `accessibility` + `flags`).
///
/// - ``keychain(accessibility:)`` — the private key lives in the regular keychain
///   (no Secure Enclave token). Protection is via plain `kSecAttrAccessible`;
///   no `kSecAttrAccessControl` is set.
public enum CryptoKeyStorage: Sendable, Hashable {

    /// Private key generated and kept inside Secure Enclave.
    ///
    /// The key material never leaves the secure hardware. Only
    /// `CryptoKeyAlgorithm.ec` is supported by Secure Enclave; passing any other
    /// algorithm to ``KeychainCryptoManagerProtocol/generateKey(descriptor:keySizeInBits:storage:authenticationContext:)``
    /// causes ``KeychainError/secureEnclaveAlgorithmInvalid``.
    ///
    /// - Parameters:
    ///   - accessibility: The `kSecAttrAccessible` value baked into the
    ///     `kSecAttrAccessControl` constraint.
    ///   - flags: Additional user-presence / biometry constraints.
    case secureEnclave(accessibility: KeychainAccessibility, flags: SecAccessControlFlags)

    /// Private key stored in the keychain (no Secure Enclave token).
    ///
    /// Protection is via `kSecAttrAccessible` only; `kSecAttrAccessControl` is
    /// **not** set, so no user-presence prompt is required to use the key.
    ///
    /// - Parameter accessibility: The `kSecAttrAccessible` value.
    case keychain(accessibility: KeychainAccessibility)
}
