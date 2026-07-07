//
//  KeychainManager+Keys.swift
//  SwiftStash
//
// Copyright (c) 2026 SwiftStash contributors
// SPDX-License-Identifier: MIT
//

#if canImport(LocalAuthentication)

import Foundation
import LocalAuthentication
import Security

extension KeychainManager {

    /// Returns a `SecKey` reference to the private key identified by the
    /// descriptor, optionally using a caller-owned authentication context.
    ///
    /// See ``KeychainCryptoManagerProtocol/loadKeyReference(_:authenticationContext:)``
    /// for the full contract.
    public func loadKeyReference(
        _ descriptor: CryptoKeyDescriptor,
        authenticationContext: LAContext? = nil
    ) throws(KeychainError) -> SecKey {
        var query = SimpleKeychain.baseKeyQuery(for: descriptor)
        query[kSecReturnRef as String] = true

        if let authenticationContext {
            query[kSecUseAuthenticationContext as String] = authenticationContext
        }

        var item: CFTypeRef?
        let status = unsafe SecItemCopyMatching(query as CFDictionary, &item)

        switch status {
            case errSecSuccess:
                guard let item, CFGetTypeID(item) == SecKeyGetTypeID() else {
                    throw KeychainError.decodeFailure
                }
                return item as! SecKey
            case errSecItemNotFound:
                throw KeychainError.itemNotFound
            default:
                throw KeychainError(fromOSStatus: status)
        }
    }

    /// Generates an asymmetric key pair and returns the public `SecKey`,
    /// optionally using a caller-owned authentication context.
    ///
    /// See ``KeychainCryptoManagerProtocol/generateKey(descriptor:keySizeInBits:storage:authenticationContext:)``
    /// for the full contract.
    public func generateKey(
        descriptor: CryptoKeyDescriptor,
        keySizeInBits: Int,
        storage: CryptoKeyStorage,
        authenticationContext: LAContext? = nil
    ) throws(KeychainError) -> SecKey {
        let algorithm = descriptor.algorithm ?? .ec

        // Validate: Secure Enclave only supports EC.
        if case .secureEnclave = storage, algorithm != .ec {
            throw KeychainError.secureEnclaveAlgorithmInvalid
        }

        try deleteKey(CryptoKeyDescriptor(tag: descriptor.tag, algorithm: nil))

        var privateAttrs: [String: Any] = [
            kSecAttrIsPermanent as String: true,
            kSecAttrApplicationTag as String: descriptor.tag
        ]

        var attributes: [String: Any] = [
            kSecAttrKeyType as String: algorithm.secValue,
            kSecAttrKeySizeInBits as String: keySizeInBits,
            kSecUseDataProtectionKeychain as String: true
        ]

        switch storage {
            case .secureEnclave(let accessibility, let flags):
                let access = try SecAccessControlBuilder.make(
                    accessibility: accessibility,
                    flags: flags
                )
                attributes[kSecAttrTokenID as String] = kSecAttrTokenIDSecureEnclave
                privateAttrs[kSecAttrAccessControl as String] = access

            case .keychain(let accessibility):
                privateAttrs[kSecAttrAccessible as String] = accessibility.secValue
        }

        if let authenticationContext {
            attributes[kSecUseAuthenticationContext as String] = authenticationContext
        }

        attributes[kSecPrivateKeyAttrs as String] = privateAttrs

        var error: Unmanaged<CFError>?
        guard let privateKey = unsafe SecKeyCreateRandomKey(attributes as CFDictionary, &error) else {
            let status: OSStatus
            if let cfError = unsafe error?.takeRetainedValue() {
                status = OSStatus(clamping: CFErrorGetCode(cfError))
            } else {
                status = errSecParam
            }
            throw KeychainError.keyGenerationFailed(status)
        }

        guard let publicKey = SecKeyCopyPublicKey(privateKey) else {
            throw KeychainError.publicKeyExtractionFailed
        }
        return publicKey
    }

    /// Deletes a cryptographic key by application tag (algorithm-agnostic when
    /// `descriptor.algorithm == nil`).
    ///
    /// See ``KeychainCryptoManagerProtocol/deleteKey(_:)`` for the full contract.
    public func deleteKey(_ descriptor: CryptoKeyDescriptor) throws(KeychainError) {
        let query = SimpleKeychain.baseKeyQuery(for: descriptor)

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError(fromOSStatus: status)
        }
    }
}

#endif
