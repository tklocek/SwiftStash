//
//  KeychainCrypto+Unavailable.swift
//  SwiftStash
//
// Copyright (c) 2026 SwiftStash contributors
// SPDX-License-Identifier: MIT
//

#if !canImport(LocalAuthentication)

import Foundation
import Security

// On platforms without the LocalAuthentication framework (tvOS), the biometric /
// Secure Enclave API surface cannot exist — but silently hiding it would leave
// users staring at "no member 'saveBiometric'" with no explanation. These
// unavailable stubs make the compiler say *why* instead.
//
// Methods that carry an `LAContext` parameter on other platforms are declared
// here without it: the type itself does not exist in this SDK, and the stubs
// are uncallable anyway — only the diagnostic matters.

private let unavailableMessage =
    "Biometric and Secure Enclave APIs require the LocalAuthentication framework, which is unavailable on this platform (tvOS)."

/// Unavailable on this platform — requires the LocalAuthentication framework.
///
/// See the iOS/macOS/watchOS/visionOS documentation for the full contract.
@available(*, unavailable, message: "Biometric and Secure Enclave APIs require the LocalAuthentication framework, which is unavailable on this platform (tvOS).")
public protocol KeychainCryptoManagerProtocol: Sendable {}

extension KeychainManager {

    /// Unavailable on this platform — requires the LocalAuthentication framework.
    @available(*, unavailable, message: "Requires the LocalAuthentication framework, which is unavailable on this platform (tvOS).")
    public func exists(
        for key: String,
        with type: KeychainItemClass
    ) -> Bool {
        fatalError(unavailableMessage)
    }

    /// Unavailable on this platform — requires the LocalAuthentication framework.
    @available(*, unavailable, message: "Requires the LocalAuthentication framework, which is unavailable on this platform (tvOS).")
    public func existsKey(_ descriptor: CryptoKeyDescriptor) -> Bool {
        fatalError(unavailableMessage)
    }

    /// Unavailable on this platform — requires the LocalAuthentication framework.
    @available(*, unavailable, message: "Requires the LocalAuthentication framework, which is unavailable on this platform (tvOS).")
    public func loadBiometric(
        for key: String,
        with type: KeychainItemClass
    ) throws(KeychainError) -> Data {
        fatalError(unavailableMessage)
    }

    /// Unavailable on this platform — requires the LocalAuthentication framework.
    @available(*, unavailable, message: "Requires the LocalAuthentication framework, which is unavailable on this platform (tvOS).")
    public func saveBiometric(
        _ value: Data,
        for key: String,
        with type: KeychainItemClass,
        accessibility: KeychainAccessibility,
        flags: SecAccessControlFlags
    ) throws(KeychainError) {
        fatalError(unavailableMessage)
    }

    /// Unavailable on this platform — requires the LocalAuthentication framework.
    @available(*, unavailable, message: "Requires the LocalAuthentication framework, which is unavailable on this platform (tvOS).")
    public func loadKeyReference(
        _ descriptor: CryptoKeyDescriptor
    ) throws(KeychainError) -> SecKey {
        fatalError(unavailableMessage)
    }

    /// Unavailable on this platform — requires the LocalAuthentication framework.
    @available(*, unavailable, message: "Requires the LocalAuthentication framework, which is unavailable on this platform (tvOS).")
    public func generateKey(
        descriptor: CryptoKeyDescriptor,
        keySizeInBits: Int,
        storage: CryptoKeyStorage
    ) throws(KeychainError) -> SecKey {
        fatalError(unavailableMessage)
    }

    /// Unavailable on this platform — requires the LocalAuthentication framework.
    @available(*, unavailable, message: "Requires the LocalAuthentication framework, which is unavailable on this platform (tvOS).")
    public func deleteKey(_ descriptor: CryptoKeyDescriptor) throws(KeychainError) {
        fatalError(unavailableMessage)
    }
}

#endif
