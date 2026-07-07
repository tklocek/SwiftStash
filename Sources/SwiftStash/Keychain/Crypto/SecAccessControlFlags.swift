//
//  SecAccessControlFlags.swift
//  SwiftStash
//
// Copyright (c) 2026 SwiftStash contributors
// SPDX-License-Identifier: MIT
//

import Foundation
import Security

/// A public wrapper for `SecAccessControlCreateFlags`, used to describe
/// the user-presence / biometry / passcode constraints applied to a keychain
/// item or a private key protected by `kSecAttrAccessControl`.
///
/// Use this `OptionSet` instead of importing `Security` directly when configuring
/// ``CryptoKeyStorage/secureEnclave(accessibility:flags:)`` or calling
/// ``KeychainCryptoManagerProtocol/saveBiometric(_:for:with:accessibility:flags:)``.
/// The package maps these values to the underlying `SecAccessControlCreateFlags`
/// internally.
///
/// ```swift
/// let flags: SecAccessControlFlags = [.privateKeyUsage]
/// ```
///
/// - Note: An empty set (`[]`) is valid and means "no additional constraints".
public struct SecAccessControlFlags: OptionSet, Sendable, Hashable {

    /// The raw bit-mask backing this `OptionSet`. Not the same value as
    /// `SecAccessControlCreateFlags.rawValue`; mapping happens internally.
    public let rawValue: UInt

    /// Creates a flag set from a raw bit-mask. Used by `OptionSet` machinery.
    public init(rawValue: UInt) { self.rawValue = rawValue }

    /// Constraint: the user must be present (Face ID, Touch ID, or passcode
    /// fallback). Maps to `SecAccessControlCreateFlags.userPresence`.
    public static let userPresence = SecAccessControlFlags(rawValue: 1 << 0)

    /// Constraint: the item is a Secure Enclave private key and may be used
    /// only for private-key operations. Maps to
    /// `SecAccessControlCreateFlags.privateKeyUsage`.
    public static let privateKeyUsage = SecAccessControlFlags(rawValue: 1 << 1)

    /// Constraint: only the currently enrolled biometric set may unlock the
    /// item (changes to enrolled biometrics invalidate it). Maps to
    /// `SecAccessControlCreateFlags.biometryCurrentSet`.
    public static let biometryCurrentSet = SecAccessControlFlags(rawValue: 1 << 2)

    /// Constraint: any enrolled biometric may unlock the item. Maps to
    /// `SecAccessControlCreateFlags.biometryAny`.
    public static let biometryAny = SecAccessControlFlags(rawValue: 1 << 3)

    /// Constraint: the device passcode is acceptable as authentication.
    /// Maps to `SecAccessControlCreateFlags.devicePasscode`.
    public static let devicePasscode = SecAccessControlFlags(rawValue: 1 << 4)

    /// The mapped Security framework flag set used internally when calling `SecAccessControlCreateWithFlags`.
    var secFlags: SecAccessControlCreateFlags {
        var flags: SecAccessControlCreateFlags = []

        if contains(.userPresence)       { flags.insert(.userPresence) }
        if contains(.privateKeyUsage)    { flags.insert(.privateKeyUsage) }
        if contains(.biometryCurrentSet) { flags.insert(.biometryCurrentSet) }
        if contains(.biometryAny)        { flags.insert(.biometryAny) }
        if contains(.devicePasscode)     { flags.insert(.devicePasscode) }

        return flags
    }
}
