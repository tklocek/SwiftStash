//
//  KeychainManager+Biometric.swift
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

    /// Reads a biometric-protected `Data` item using a pre-satisfied `LAContext`.
    ///
    /// See ``KeychainCryptoManagerProtocol/loadBiometric(for:with:authenticationContext:)``
    /// for the full contract.
    public func loadBiometric(
        for key: String,
        with type: KeychainItemClass,
        authenticationContext: LAContext
    ) throws(KeychainError) -> Data {
        var query: [String: Any] = [
            kSecClass as String: type.secValue,
            kSecUseDataProtectionKeychain as String: true,
            kSecAttrSynchronizable as String: kSecAttrSynchronizableAny,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecUseAuthenticationContext as String: authenticationContext
        ]
        SimpleKeychain.applyIdentity(to: &query, key: key, type: type, service: service)

        var item: CFTypeRef?
        let status = unsafe SecItemCopyMatching(query as CFDictionary, &item)

        switch status {
            case errSecSuccess:
                guard let data = item as? Data else {
                    throw KeychainError.decodeFailure
                }
                return data
            case errSecItemNotFound:
                throw KeychainError.itemNotFound
            default:
                throw KeychainError(fromOSStatus: status)
        }
    }

    /// Writes a biometric-protected `Data` item using the delete-then-add pattern.
    ///
    /// See ``KeychainCryptoManagerProtocol/saveBiometric(_:for:with:accessibility:flags:)``
    /// for the full contract.
    public func saveBiometric(
        _ value: Data,
        for key: String,
        with type: KeychainItemClass,
        accessibility: KeychainAccessibility,
        flags: SecAccessControlFlags
    ) throws(KeychainError) {
        try SimpleKeychain.delete(
            for: key,
            type: type,
            service: service
        )

        let access = try SecAccessControlBuilder.make(
            accessibility: accessibility,
            flags: flags
        )

        try SimpleKeychain.saveWithAccessControl(
            value,
            for: key,
            type: type,
            accessControl: access,
            service: service
        )
    }
}

#endif
