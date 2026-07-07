//
//  CryptoKeyAlgorithm.swift
//  SwiftStash
//
// Copyright (c) 2026 SwiftStash contributors
// SPDX-License-Identifier: MIT
//

import Foundation
import Security

/// An asymmetric key algorithm supported by SwiftStash for cryptographic
/// key operations.
///
/// Each case maps to a `kSecAttrKeyType*` constant used when generating or
/// querying cryptographic keys via `SecKey*` APIs.
///
/// ```swift
/// let descriptor = CryptoKeyDescriptor(
///     stringTag: "com.example.binding.user42",
///     algorithm: .ec
/// )
/// ```
public enum CryptoKeyAlgorithm: Sendable, Hashable {

    /// Elliptic Curve over a NIST prime field (P-256).
    /// Maps to `kSecAttrKeyTypeECSECPrimeRandom`.
    case ec

    /// RSA key.
    /// Maps to `kSecAttrKeyTypeRSA`.
    case rsa

    /// The corresponding `CFString` constant from the Security framework
    /// used as the value for `kSecAttrKeyType`.
    var secValue: CFString {
        switch self {
            case .ec:  return kSecAttrKeyTypeECSECPrimeRandom
            case .rsa: return kSecAttrKeyTypeRSA
        }
    }
}
