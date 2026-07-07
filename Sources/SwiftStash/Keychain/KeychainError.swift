//
//  KeychainError.swift
//  SwiftStash
//
// Copyright (c) 2026 SwiftStash contributors
// SPDX-License-Identifier: MIT
//

import Foundation

public enum KeychainError: LocalizedError, Sendable, Equatable {
    /// Invalid data provided for keychain operation.
    /// Typically occurs when trying to store an empty or malformed value.
    case invalidData
    
    /// The item cannot be found.
    case itemNotFound
    
    /// The item already exists.
    case duplicateItem
    
    /// The provided attributes are not valid for the selected class.
    case incorrectAttributeForClass
    
    /// The app lacks the necessary entitlements to perform keychain operations.
    case missingEntitlement
    
    /// Write permissions error.
    case writePermission
    
    /// Failed to decode keychain item.
    case decodeFailure
    
    /// Invalid parameters passed to Keychain API.
    case paramError
    
    /// Keychain service is not available (e.g., device locked or inaccessible).
    case notAvailable
    
    /// The user cancelled the operation.
    case userCanceled
    
    /// Authorization and/or authentication failed.
    case authFailed

    /// Unexpected keychain error with OSStatus code.
    case unexpected(OSStatus)

    /// User interaction is required but cannot be presented (e.g. while
    /// querying with `LAContext.interactionNotAllowed = true`, or in a
    /// background execution context).
    ///
    /// Maps from `errSecInteractionRequired` and `errSecInteractionNotAllowed`.
    case interactionRequired

    /// `SecAccessControlCreateWithFlags` returned `nil` while building a
    /// `kSecAttrAccessControl` value (typically the Security framework rejected
    /// the requested combination of accessibility + flags on this platform).
    case accessControlCreationFailed

    /// `SecKeyCreateRandomKey` returned `nil`. The associated `OSStatus`
    /// captures the underlying Security framework error code, if any.
    case keyGenerationFailed(OSStatus)

    /// `SecKeyCopyPublicKey` returned `nil` after a successful private-key
    /// generation; the public half could not be extracted.
    case publicKeyExtractionFailed

    /// A `CryptoKeyStorage.secureEnclave(...)` was requested with an algorithm
    /// other than `CryptoKeyAlgorithm.ec`. The Secure Enclave supports only
    /// EC P-256 keys.
    case secureEnclaveAlgorithmInvalid

    // LocalizedError's hook: `localizedDescription` (via NSError bridging) is derived
    // from this, so the messages surface even through an untyped `any Error`.
    public var errorDescription: String? {
        switch self {
            case .invalidData:
                return "Invalid data provided for keychain operation."
                
            case .itemNotFound:
                return "The requested item was not found in the keychain."
                
            case .duplicateItem:
                return "An item with the same attributes already exists in the keychain."
                
            case .incorrectAttributeForClass:
                return "The provided attributes are not valid for this item class."
                
            case .missingEntitlement:
                return "The app lacks required entitlements for keychain access."
                
            case .writePermission:
                return "Keychain write permission denied."
                
            case .decodeFailure:
                return "Unable to decode the stored keychain data."
                
            case .paramError:
                return "Invalid parameters were passed to the keychain API."
                
            case .notAvailable:
                return "Keychain service is not available (e.g., device is locked)."
                
            case .userCanceled:
                return "The user cancelled the keychain operation."
                
            case .authFailed:
                return "Keychain authorization or authentication failed."
                
            case .unexpected(let status):
                return "Unexpected keychain error (OSStatus: \(status))."

            case .interactionRequired:
                return "User interaction is required but cannot be presented."

            case .accessControlCreationFailed:
                return "Failed to create a SecAccessControl with the requested flags."

            case .keyGenerationFailed(let status):
                return "Failed to generate cryptographic key (OSStatus: \(status))."

            case .publicKeyExtractionFailed:
                return "Failed to extract the public key from the generated key pair."

            case .secureEnclaveAlgorithmInvalid:
                return "The Secure Enclave only supports EC P-256 keys."
        }
    }
    
    /// Converts a raw `OSStatus` into a typed `KeychainError`.
    ///
    /// Complete list of codes is here: [Apple Security Result Codes](https://developer.apple.com/documentation/security/security-framework-result-codes)
    public init(fromOSStatus status: OSStatus) {
        self = switch status {
            // errSecSuccess: is not an error, but Apple use this code as a Success. Should be handle separately!
            case errSecSuccess: .unexpected(status)
            
            case errSecDataTooLarge: .invalidData
            case errSecItemNotFound: .itemNotFound
            case errSecDuplicateItem: .duplicateItem
            case errSecAuthFailed: .authFailed
            case errSecInteractionRequired, errSecInteractionNotAllowed: .interactionRequired
            case errSecUserCanceled: .userCanceled
            case errSecParam, errSecUnimplemented: .paramError
            case errSecNotAvailable: .notAvailable
            case errSecMissingEntitlement: .missingEntitlement
            case errSecWrPerm: .writePermission
            case errSecDecode: .decodeFailure
                
            default: .unexpected(status)
        }
    }
    
}
