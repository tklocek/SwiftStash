//
//  SimpleKeychain.swift
//  SwiftStash
//
// Copyright (c) 2026 SwiftStash contributors
// SPDX-License-Identifier: MIT
//

import Foundation
import Security

/// A simplified wrapper for interacting with the system Keychain across all supported item classes.
///
/// Supports common CRUD operations and auto-generates queries depending on the selected `KeychainItemClass`.
///
/// Query semantics:
/// - `save` writes the item with the exact `synchronizable` attribute requested.
/// - `load`, `update`, and `delete` match items regardless of their synchronizable state
///   (`kSecAttrSynchronizableAny`), so an item saved as synchronizable is still found by a
///   caller configured with `synchronizable == false` and vice versa.
/// - All queries target the data protection keychain (`kSecUseDataProtectionKeychain`), so
///   `kSecAttrAccessible` is honored on macOS as well. On macOS this requires the app to be
///   signed with an application identifier (any normally signed app qualifies).
///
/// This is an internal implementation detail. Users should use `@SecureStash` or `KeychainManager` instead.
enum SimpleKeychain {

    /// How a query matches the `kSecAttrSynchronizable` attribute.
    private enum SyncMatch {
        /// Write/require the exact value (used when creating items).
        case exact(Bool)
        /// Match items regardless of their synchronizable state (used for lookups).
        case any
    }

    /// Saves data to the Keychain using auto-generated attributes.
    ///
    /// - Parameters:
    ///   - value: The data to store (encoded as `Data`).
    ///   - key: A unique key to identify the item. For passwords, this is the `kSecAttrAccount`; for other types, it is mapped accordingly.
    ///   - type: The keychain item class. Defaults to `.genericPassword`.
    ///   - accessible: Access level defining when the item is available. Defaults to `.whenPasscodeSetThisDeviceOnly`.
    ///   - synchronizable: Whether the item should be synced to iCloud (if supported). Defaults to `false`.
    ///   - service: Namespaces `.genericPassword` items — typically your app’s bundle ID (e.g. `"com.example.app"`). Ignored for `.internetPassword`, whose identity is the account plus the domain carried by the item class.
    ///
    /// - Throws: `KeychainError` if the operation fails.
    static func save(
        _ value: Data,
        for key: String,
        type: KeychainItemClass = .genericPassword,
        accessible: KeychainAccessibility = .whenPasscodeSetThisDeviceOnly,
        synchronizable: Bool = false,
        service: String
    ) throws(KeychainError) {
        if synchronizable && accessible.isThisDeviceOnly {
            Logging.logError(
                "save: isSynchronizable is incompatible with \(accessible) — iCloud Keychain cannot sync *ThisDeviceOnly items. The operation will fail.",
                key: key,
                type: "Data",
                storageType: .keychain
            )
        }

        let query = buildBaseQuery(
            for: key,
            type: type,
            syncMatch: .exact(synchronizable),
            service: service,
            value: value,
            accessible: accessible
        )

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError(fromOSStatus: status)
        }
    }

    /// Updates an existing item in the Keychain.
    ///
    /// Matches the item regardless of its synchronizable state.
    ///
    /// - Parameters:
    ///   - value: The new data to update.
    ///   - key: The key identifying the item.
    ///   - type: The item class (default: `.genericPassword`).
    ///   - accessible: When provided, the item's accessibility is re-applied alongside the new
    ///     value, so an accessibility change in code propagates to items created by earlier
    ///     versions. Pass `nil` to leave the stored accessibility untouched.
    ///   - service: Namespaces `.genericPassword` items — typically your app’s bundle ID (e.g. `"com.example.app"`). Ignored for `.internetPassword`, whose identity is the account plus the domain carried by the item class.
    ///
    /// - Throws: `KeychainError` if the operation fails.
    static func update(
        _ value: Data,
        for key: String,
        type: KeychainItemClass = .genericPassword,
        accessible: KeychainAccessibility? = nil,
        service: String
    ) throws(KeychainError) {
        let query = buildBaseQuery(
            for: key,
            type: type,
            syncMatch: .any,
            service: service
        )

        var attributesToUpdate: [String: Any] = [
            kSecValueData as String: value
        ]
        if let accessible {
            attributesToUpdate[kSecAttrAccessible as String] = accessible.secValue
        }

        let status = SecItemUpdate(query as CFDictionary, attributesToUpdate as CFDictionary)
        guard status == errSecSuccess else {
            throw KeychainError(fromOSStatus: status)
        }
    }

    /// Loads data from the Keychain for the given key.
    ///
    /// Matches the item regardless of its synchronizable state.
    ///
    /// - Parameters:
    ///   - key: The key to retrieve.
    ///   - type: The item class.
    ///   - service: Namespaces `.genericPassword` items — typically your app’s bundle ID (e.g. `"com.example.app"`). Ignored for `.internetPassword`, whose identity is the account plus the domain carried by the item class.
    ///
    /// - Returns: The stored `Data` if found; otherwise `nil`.
    ///
    /// - Throws: `KeychainError.unexpected` on failure.
    static func load(
        for key: String,
        type: KeychainItemClass = .genericPassword,
        service: String
    ) throws(KeychainError) -> Data? {
        var query = buildBaseQuery(
            for: key,
            type: type,
            syncMatch: .any,
            service: service
        )

        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = unsafe SecItemCopyMatching(query as CFDictionary, &item)

        guard status != errSecItemNotFound else { return nil }
        guard status == errSecSuccess else {
            throw KeychainError(fromOSStatus: status)
        }

        return item as? Data
    }

    /// Deletes a Keychain item identified by the given key.
    ///
    /// Matches the item regardless of its synchronizable state.
    ///
    /// - Parameters:
    ///   - key: The unique key used to locate the item.
    ///   - type: The item class.
    ///   - service: Namespaces `.genericPassword` items — typically your app’s bundle ID (e.g. `"com.example.app"`). Ignored for `.internetPassword`, whose identity is the account plus the domain carried by the item class.
    ///
    /// - Throws: `KeychainError` on failure.
    static func delete(
        for key: String,
        type: KeychainItemClass = .genericPassword,
        service: String
    ) throws(KeychainError) {
        let query = buildBaseQuery(
            for: key,
            type: type,
            syncMatch: .any,
            service: service
        )

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError(fromOSStatus: status)
        }
    }

    /// Adds a `kSecAttrAccessControl`-protected item using `SecItemAdd`.
    ///
    /// Used for biometric-/user-presence-protected items. `kSecAttrSynchronizable`
    /// is forced to `false` because access-control items cannot be iCloud-synced.
    ///
    /// - Parameters:
    ///   - value: The data to store.
    ///   - key: The account/label depending on item type.
    ///   - type: The keychain item class.
    ///   - accessControl: A pre-built `SecAccessControl` describing accessibility + flags.
    ///   - service: Namespaces `.genericPassword` items — typically your app’s bundle ID (e.g. `"com.example.app"`). Ignored for `.internetPassword`, whose identity is the account plus the domain carried by the item class.
    ///
    /// - Throws: `KeychainError` if `SecItemAdd` fails.
    static func saveWithAccessControl(
        _ value: Data,
        for key: String,
        type: KeychainItemClass,
        accessControl: SecAccessControl,
        service: String
    ) throws(KeychainError) {
        var attributes: [String: Any] = [
            kSecClass as String: type.secValue,
            kSecUseDataProtectionKeychain as String: true,
            kSecValueData as String: value,
            kSecAttrAccessControl as String: accessControl,
            kSecAttrSynchronizable as String: cfBoolean(false)
        ]
        applyIdentity(to: &attributes, key: key, type: type, service: service)

        let status = SecItemAdd(attributes as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError(fromOSStatus: status)
        }
    }

    /// Builds the base query skeleton for a cryptographic key
    /// (`kSecClass = kSecClassKey`) identified by `descriptor`.
    ///
    /// Includes `kSecAttrKeyType` only when `descriptor.algorithm` is non-nil,
    /// supporting algorithm-agnostic probing/deletion.
    ///
    /// - Parameter descriptor: Identifies the key by application tag + (optional) algorithm.
    /// - Returns: A base query dictionary ready to be augmented with
    ///   `kSecReturnRef`, `kSecMatchLimit`, etc.
    static func baseKeyQuery(for descriptor: CryptoKeyDescriptor) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecUseDataProtectionKeychain as String: true,
            kSecAttrApplicationTag as String: descriptor.tag
        ]
        if let algorithm = descriptor.algorithm {
            query[kSecAttrKeyType as String] = algorithm.secValue
        }
        return query
    }

    /// Converts a Swift `Bool` into a `CFBoolean` for use in Keychain attributes.
    ///
    /// - Parameter value: A standard `Bool` value.
    /// - Returns: A `CFBoolean` (either `kCFBooleanTrue` or `kCFBooleanFalse`).
    private static func cfBoolean(_ value: Bool) -> CFBoolean {
        value ? kCFBooleanTrue : kCFBooleanFalse
    }

    /// Applies the identity attributes (`kSecAttrService`/`kSecAttrAccount`/
    /// `kSecAttrServer`/`kSecAttrLabel`) for the given item class onto an
    /// existing query dictionary.
    ///
    /// - Parameters:
    ///   - query: The query dictionary to mutate.
    ///   - key: The account or label depending on item type.
    ///   - type: The keychain item class.
    ///   - service: Service identifier; not applied for `.internetPassword`
    ///     (identity is the account plus the item class's domain).
    static func applyIdentity(
        to query: inout [String: Any],
        key: String,
        type: KeychainItemClass,
        service: String
    ) {
        switch type {
            case .genericPassword:
                query[kSecAttrService as String] = service
                query[kSecAttrAccount as String] = key

            case .internetPassword(let domain):
                query[kSecAttrAccount as String] = key
                query[kSecAttrServer as String] = domain
                query[kSecAttrProtocol as String] = kSecAttrProtocolHTTPS

            case .certificate, .key, .identity:
                query[kSecAttrLabel as String] = key
        }
    }

    /// Constructs a base Keychain query dictionary for all item classes.
    ///
    /// - Parameters:
    ///   - key: The account or label depending on item type.
    ///   - type: The keychain item class.
    ///   - syncMatch: How to match the `kSecAttrSynchronizable` attribute.
    ///   - service: Stored under `kSecAttrService` for `.genericPassword`; not applied
    ///     for `.internetPassword` (the server comes from the item class's domain).
    ///   - value: Optional `Data` to insert as the value.
    ///   - accessible: Optional accessibility level (`kSecAttrAccessible`).
    ///
    /// - Returns: A Keychain query dictionary for use with `SecItemAdd`, `SecItemUpdate`, etc.
    private static func buildBaseQuery(
        for key: String,
        type: KeychainItemClass,
        syncMatch: SyncMatch,
        service: String,
        value: Data? = nil,
        accessible: KeychainAccessibility? = nil
    ) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: type.secValue,
            // Route to the data protection keychain so kSecAttrAccessible is honored on
            // macOS too (ignored on iOS-family platforms, where it is the only keychain).
            kSecUseDataProtectionKeychain as String: true
        ]

        switch syncMatch {
            case .exact(let synchronizable):
                query[kSecAttrSynchronizable as String] = cfBoolean(synchronizable)
            case .any:
                query[kSecAttrSynchronizable as String] = kSecAttrSynchronizableAny
        }

        if let value { query[kSecValueData as String] = value }
        if let accessible { query[kSecAttrAccessible as String] = accessible.secValue }

        applyIdentity(to: &query, key: key, type: type, service: service)
        return query
    }

}
