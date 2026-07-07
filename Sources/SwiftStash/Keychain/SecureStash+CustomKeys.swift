//
//  SecureStash+CustomKeys.swift
//  SwiftStash
//
// Copyright (c) 2026 SwiftStash contributors
// SPDX-License-Identifier: MIT
//

import Foundation

// MARK: - Data Storage

public extension SecureStash {
    /// Creates a property wrapper for storing Data values in the Keychain,
    /// using a string-backed key type (e.g. `enum SecretsKey: String`).
    /// - Parameters:
    ///   - key: The key to store the value under; its `rawValue` is used as the Keychain account.
    ///   - service: Service identifier (defaults to the globally configured value).
    ///   - accessibility: Keychain accessibility level (defaults to global or `.whenPasscodeSetThisDeviceOnly`).
    ///   - isSynchronizable: Whether to sync via iCloud (defaults to global or `false`).
    ///   - itemClass: Keychain item class (defaults to global or `.genericPassword`).
    init(
        key: some RawRepresentable<String>,
        service: String? = nil,
        accessibility: KeychainAccessibility? = nil,
        isSynchronizable: Bool? = nil,
        itemClass: KeychainItemClass? = nil
    ) where Value == Data? {
        self.init(
            key: key.rawValue,
            service: service,
            accessibility: accessibility,
            isSynchronizable: isSynchronizable,
            itemClass: itemClass
        )
    }
}

// MARK: - String Storage

public extension SecureStash where Value == String? {
    /// Creates a property wrapper for storing String values in the Keychain,
    /// using a string-backed key type.
    /// - Parameters:
    ///   - key: The key to store the value under; its `rawValue` is used as the Keychain account.
    ///   - service: Service identifier (defaults to the globally configured value).
    ///   - accessibility: Keychain accessibility level (defaults to global or `.whenPasscodeSetThisDeviceOnly`).
    ///   - isSynchronizable: Whether to sync via iCloud (defaults to global or `false`).
    ///   - itemClass: Keychain item class (defaults to global or `.genericPassword`).
    init(
        key: some RawRepresentable<String>,
        service: String? = nil,
        accessibility: KeychainAccessibility? = nil,
        isSynchronizable: Bool? = nil,
        itemClass: KeychainItemClass? = nil
    ) {
        self.init(
            key: key.rawValue,
            service: service,
            accessibility: accessibility,
            isSynchronizable: isSynchronizable,
            itemClass: itemClass
        )
    }
}

// MARK: - Codable Storage

public extension SecureStash {
    /// Creates a property wrapper for storing Codable types in the Keychain using JSON encoding,
    /// using a string-backed key type.
    /// - Parameters:
    ///   - key: The key to store the value under; its `rawValue` is used as the Keychain account.
    ///   - service: Service identifier (defaults to the globally configured value).
    ///   - accessibility: Keychain accessibility level (defaults to global or `.whenPasscodeSetThisDeviceOnly`).
    ///   - isSynchronizable: Whether to sync via iCloud (defaults to global or `false`).
    ///   - itemClass: Keychain item class (defaults to global or `.genericPassword`).
    ///   - encoder: Custom JSON encoder (defaults to a standard `JSONEncoder`). Configure it
    ///     fully before passing it in; the wrapper keeps using this instance, so it must not
    ///     be mutated afterwards.
    ///   - decoder: Custom JSON decoder (defaults to a standard `JSONDecoder`). The same rule
    ///     applies: configure before passing, never mutate afterwards.
    init<T: Codable>(
        codable key: some RawRepresentable<String>,
        service: String? = nil,
        accessibility: KeychainAccessibility? = nil,
        isSynchronizable: Bool? = nil,
        itemClass: KeychainItemClass? = nil,
        encoder: JSONEncoder? = nil,
        decoder: JSONDecoder? = nil
    ) where Value == T? {
        self.init(
            codable: key.rawValue,
            service: service,
            accessibility: accessibility,
            isSynchronizable: isSynchronizable,
            itemClass: itemClass,
            encoder: encoder,
            decoder: decoder
        )
    }
}
