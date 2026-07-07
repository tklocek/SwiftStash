//
//  CryptoKeyDescriptor.swift
//  SwiftStash
//
// Copyright (c) 2026 SwiftStash contributors
// SPDX-License-Identifier: MIT
//

import Foundation

/// Identifies a cryptographic key in the keychain by its application tag
/// (`kSecAttrApplicationTag`) and, optionally, by its algorithm.
///
/// Pass `algorithm: nil` for algorithm-agnostic operations — primarily probing
/// for existence (``KeychainCryptoManagerProtocol/existsKey(_:)``) and deletion
/// (``KeychainCryptoManagerProtocol/deleteKey(_:)``) — when the caller does not
/// know or care whether the stored key is `.ec` or `.rsa`.
///
/// ```swift
/// // Tagged key with explicit algorithm — typical for load/generate.
/// let signing = CryptoKeyDescriptor(
///     stringTag: "com.example.binding.user42",
///     algorithm: .ec
/// )
///
/// // Algorithm-agnostic — typical for probe/delete.
/// let probe = CryptoKeyDescriptor(stringTag: "com.example.binding.user42")
/// ```
public struct CryptoKeyDescriptor: Sendable, Hashable {

    /// The application tag bytes. Maps to `kSecAttrApplicationTag`.
    public let tag: Data

    /// The key algorithm if known; `nil` for algorithm-agnostic operations.
    public let algorithm: CryptoKeyAlgorithm?

    /// Creates a descriptor from raw application-tag bytes.
    ///
    /// - Parameters:
    ///   - tag: The application-tag bytes (`kSecAttrApplicationTag`).
    ///   - algorithm: The key algorithm, or `nil` to match any algorithm.
    public init(tag: Data, algorithm: CryptoKeyAlgorithm? = nil) {
        self.tag = tag
        self.algorithm = algorithm
    }

    /// Creates a descriptor from a string application tag (encoded as UTF-8).
    ///
    /// - Parameters:
    ///   - stringTag: The application tag as a string. Encoded as UTF-8.
    ///   - algorithm: The key algorithm, or `nil` to match any algorithm.
    public init(stringTag: String, algorithm: CryptoKeyAlgorithm? = nil) {
        self.init(tag: Data(stringTag.utf8), algorithm: algorithm)
    }
}
