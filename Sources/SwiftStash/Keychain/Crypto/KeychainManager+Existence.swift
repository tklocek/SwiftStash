//
//  KeychainManager+Existence.swift
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

    /// Probes existence of a generic-/internet-password item without surfacing
    /// biometric prompts.
    ///
    /// See ``KeychainCryptoManagerProtocol/exists(for:with:authenticationContext:)``
    /// for the full contract.
    public func exists(
        for key: String,
        with type: KeychainItemClass,
        authenticationContext: LAContext? = nil
    ) -> Bool {
        let probe: LAContext
        if let authenticationContext {
            probe = authenticationContext
        } else {
            probe = LAContext()
            probe.interactionNotAllowed = true
        }

        var query: [String: Any] = [
            kSecClass as String: type.secValue,
            kSecUseDataProtectionKeychain as String: true,
            kSecAttrSynchronizable as String: kSecAttrSynchronizableAny,
            kSecReturnAttributes as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecUseAuthenticationContext as String: probe
        ]
        SimpleKeychain.applyIdentity(to: &query, key: key, type: type, service: service)

        var item: CFTypeRef?
        let status = unsafe SecItemCopyMatching(query as CFDictionary, &item)
        return status == errSecSuccess || status == errSecInteractionNotAllowed
    }

    /// Probes existence of a cryptographic key by application tag.
    ///
    /// See ``KeychainCryptoManagerProtocol/existsKey(_:)`` for the full contract.
    public func existsKey(_ descriptor: CryptoKeyDescriptor) -> Bool {
        var query = SimpleKeychain.baseKeyQuery(for: descriptor)
        query[kSecReturnRef as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = unsafe SecItemCopyMatching(query as CFDictionary, &item)
        return status == errSecSuccess && item != nil
    }
}

#endif
