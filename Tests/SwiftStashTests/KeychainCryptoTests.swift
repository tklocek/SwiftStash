//
//  KeychainCryptoTests.swift
//  SwiftStash
//
// Copyright (c) 2026 SwiftStash contributors
// SPDX-License-Identifier: MIT
//

#if canImport(LocalAuthentication)

import Foundation
import Security
import Testing
@testable import SwiftStash

/// Tests for the biometric / Secure Enclave / cryptographic-key API surface.
///
/// Only the keychain-free parts run here: flag mapping, descriptors, error
/// mapping, `SecAccessControl` construction, and validation that fires before
/// any `SecItem` call. Real keychain and Secure Enclave behaviour is validated
/// via the example app on device, matching the rest of the keychain suite.
struct KeychainCryptoTests {

    // MARK: - SecAccessControlFlags

    @Test
    func `Each access control flag maps to its Security framework counterpart`() {
        #expect(SecAccessControlFlags.userPresence.secFlags == .userPresence)
        #expect(SecAccessControlFlags.privateKeyUsage.secFlags == .privateKeyUsage)
        #expect(SecAccessControlFlags.biometryCurrentSet.secFlags == .biometryCurrentSet)
        #expect(SecAccessControlFlags.biometryAny.secFlags == .biometryAny)
        #expect(SecAccessControlFlags.devicePasscode.secFlags == .devicePasscode)
    }

    @Test
    func `Combined access control flags map to the combined Security flag set`() {
        let flags: SecAccessControlFlags = [.userPresence, .privateKeyUsage]

        #expect(flags.secFlags == [.userPresence, .privateKeyUsage])
    }

    @Test
    func `Empty access control flags map to an empty Security flag set`() {
        let flags: SecAccessControlFlags = []

        #expect(flags.secFlags == [])
    }

    // MARK: - SecAccessControlBuilder

    @Test
    func `Access control builds for a typical biometric configuration`() throws {
        _ = try SecAccessControlBuilder.make(
            accessibility: .whenUnlockedThisDeviceOnly,
            flags: [.userPresence]
        )
    }

    @Test
    func `Access control builds for a Secure Enclave key configuration`() throws {
        _ = try SecAccessControlBuilder.make(
            accessibility: .whenUnlockedThisDeviceOnly,
            flags: [.privateKeyUsage]
        )
    }

    // MARK: - CryptoKeyDescriptor

    @Test
    func `String tag is encoded as UTF-8 bytes`() {
        let descriptor = CryptoKeyDescriptor(stringTag: "com.example.binding.user42")

        #expect(descriptor.tag == Data("com.example.binding.user42".utf8))
    }

    @Test
    func `Descriptor is algorithm-agnostic by default`() {
        let descriptor = CryptoKeyDescriptor(stringTag: "com.example.probe")

        #expect(descriptor.algorithm == nil)
    }

    // MARK: - KeychainError

    @Test
    func `errSecInteractionRequired maps to interactionRequired`() {
        #expect(KeychainError(fromOSStatus: errSecInteractionRequired) == .interactionRequired)
    }

    @Test
    func `errSecInteractionNotAllowed maps to interactionRequired, not authFailed`() {
        // A prompt-free probe (LAContext.interactionNotAllowed) hitting a protected
        // item yields errSecInteractionNotAllowed — that is "interaction needed",
        // not a failed authentication.
        #expect(KeychainError(fromOSStatus: errSecInteractionNotAllowed) == .interactionRequired)
    }

    @Test
    func `Crypto error cases provide a description`() {
        let errors: [KeychainError] = [
            .interactionRequired,
            .accessControlCreationFailed,
            .keyGenerationFailed(errSecParam),
            .publicKeyExtractionFailed,
            .secureEnclaveAlgorithmInvalid
        ]

        for error in errors {
            #expect(error.errorDescription?.isEmpty == false)
        }
    }

    // MARK: - Key generation validation

    @Test
    func `Secure Enclave storage rejects RSA before touching the keychain`() {
        let manager = KeychainManager(service: "swiftstash.tests.crypto.se-rsa")
        let descriptor = CryptoKeyDescriptor(
            stringTag: "swiftstash.tests.crypto.se-rsa.tag",
            algorithm: .rsa
        )

        #expect(throws: KeychainError.secureEnclaveAlgorithmInvalid) {
            _ = try manager.generateKey(
                descriptor: descriptor,
                keySizeInBits: 2048,
                storage: .secureEnclave(
                    accessibility: .whenUnlockedThisDeviceOnly,
                    flags: [.privateKeyUsage]
                )
            )
        }
    }
}

#endif
