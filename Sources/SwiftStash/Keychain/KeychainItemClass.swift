//
//  KeychainItemClass.swift
//  SwiftStash
//
// Copyright (c) 2026 SwiftStash contributors
// SPDX-License-Identifier: MIT
//

import Foundation

/// A representation of the various item classes that can be stored in the keychain.
///
/// This enum maps to the `kSecClass` values used by the Keychain Services API. Each case determines
/// the type of keychain item and influences which attributes are required or supported.
///
/// > Important: SwiftStash's data-based save/update paths support the two password
/// > classes only. `.certificate`, `.key`, and `.identity` items cannot be created
/// > through `kSecValueData` — the Security framework expects `kSecValueRef` for
/// > them — so writes with those classes fail at the SecItem layer. The cases exist
/// > for reading or deleting items created elsewhere; `SecureStashHelpers.allKeys`
/// > and `.clearAll` reject them outright.
public enum KeychainItemClass: Sendable, Hashable {
    
    /// Represents a generic password item (e.g. API tokens, app secrets).
    /// Maps to `kSecClassGenericPassword`.
    case genericPassword
    
    /// Represents an internet password item, typically used for web credentials.
    /// Maps to `kSecClassInternetPassword`.
    case internetPassword(domain: String)
    
    /// Represents a certificate item (e.g. X.509 certificate).
    /// Maps to `kSecClassCertificate`.
    case certificate
    
    /// Represents a cryptographic key (private or public).
    /// Maps to `kSecClassKey`.
    case key
    
    /// Represents an identity, which includes both a certificate and a private key.
    /// Maps to `kSecClassIdentity`.
    case identity
    
    /// Returns the corresponding `CFString` constant from Security framework for use in Keychain queries.
    var secValue: CFString {
        switch self {
            case .genericPassword: return kSecClassGenericPassword
            case .internetPassword: return kSecClassInternetPassword
            case .certificate: return kSecClassCertificate
            case .key: return kSecClassKey
            case .identity: return kSecClassIdentity
        }
    }
}
