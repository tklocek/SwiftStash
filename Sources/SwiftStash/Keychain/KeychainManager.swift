//
//  KeychainManager.swift
//  SwiftStash
//
// Copyright (c) 2026 SwiftStash contributors
// SPDX-License-Identifier: MIT
//

import Foundation

/// A protocol defining methods for interacting with the system Keychain on Apple platforms.
/// Enables storing, retrieving, updating, and deleting secure data.
/// Supports both `Data` and `Codable` types.
///
/// Implementations must conform to `Sendable`.
public protocol KeychainManagerProtocol: Sendable {
    func save<T: Encodable>(
        _ value: T,
        for key: String,
        with type: KeychainItemClass,
        accessibility: KeychainAccessibility?,
        isSynchronizable: Bool?
    ) throws(KeychainError)
    func save(
        _ value: Data,
        for key: String,
        with type: KeychainItemClass,
        accessibility: KeychainAccessibility?,
        isSynchronizable: Bool?
    ) throws(KeychainError)
    func load(for key: String, with type: KeychainItemClass) throws(KeychainError) -> Data
    func load<T: Decodable>(for key: String, with type: KeychainItemClass) throws(KeychainError) -> T
    func update(
        _ value: Data,
        for key: String,
        with type: KeychainItemClass,
        accessibility: KeychainAccessibility?
    ) throws(KeychainError)
    func update<T: Encodable>(
        _ value: T,
        for key: String,
        with type: KeychainItemClass,
        accessibility: KeychainAccessibility?
    ) throws(KeychainError)
    func delete(for key: String, with type: KeychainItemClass) throws(KeychainError)
}

// CRUD goes through `KeychainRuntime.shared.backend` — the same swappable backend
// `@SecureStash` uses, so tests run against the in-memory mock. The Crypto extensions
// (biometric items, SecKey APIs) talk to the Security framework directly: their
// surface (SecAccessControl, LAContext, SecKey) has no meaningful in-memory analogue.
public final class KeychainManager: KeychainManagerProtocol {
    private let accessibility: KeychainAccessibility
    private let isSynchronizable: Bool
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    // Internal so the Crypto extensions (separate files, same module) can build queries.
    let service: String
    
    /// Creates a new instance of `KeychainManager` with configurable defaults for all keychain operations.
    ///
    /// - Parameters:
    ///   - accessibility: Default accessibility level for stored items.
    ///     This can be overridden per call in `save` or `update`.
    ///
    ///   - isSynchronizable: Default iCloud synchronizability for stored items.
    ///     This can also be overridden per call in `save` or `update`.
    ///
    ///   - service: A unique identifier used to namespace your Keychain entries.
    ///     This is commonly your app's bundle identifier (e.g. `"com.example.myapp"`). It is
    ///     not a Keychain access group and does not grant sharing between targets. It applies
    ///     to `.genericPassword` items only — `.internetPassword` items are identified by
    ///     account + domain, so the service does not participate in their queries.
    ///
    ///   - encoder: The `JSONEncoder` instance used when encoding `Encodable` values to `Data`.
    ///     Inject a custom encoder if your app needs specific strategies (e.g., date formatting, key casing).
    ///     Configure it fully before passing it in; the manager keeps using this instance, so it
    ///     must not be mutated afterwards.
    ///
    ///   - decoder: The `JSONDecoder` instance used when decoding `Decodable` values from `Data`.
    ///     Inject a custom decoder if your stored data uses non-default strategies. The same rule
    ///     applies: configure before passing, never mutate afterwards.
    ///
    /// ```swift
    /// let encoder = JSONEncoder()
    /// encoder.dateEncodingStrategy = .iso8601
    ///
    /// let decoder = JSONDecoder()
    /// decoder.dateDecodingStrategy = .iso8601
    ///
    /// let keychain = KeychainManager(
    ///     accessibility: .whenPasscodeSetThisDeviceOnly,
    ///     isSynchronizable: false,
    ///     service: Bundle.main.bundleIdentifier!,
    ///     encoder: encoder,
    ///     decoder: decoder
    /// )
    /// ```
    public init(
        accessibility: KeychainAccessibility = .whenPasscodeSetThisDeviceOnly,
        isSynchronizable: Bool = false,
        service: String,
        encoder: JSONEncoder = JSONEncoder(),
        decoder: JSONDecoder = JSONDecoder()
    ) {
        self.accessibility = accessibility
        self.isSynchronizable = isSynchronizable
        self.service = service
        self.encoder = encoder
        self.decoder = decoder
    }
    
    /// Save a Codable value to the Keychain.
    ///
    /// This method does **not overwrite** an existing value.
    /// If an item with the same `key` and `type` already exists,
    /// it throws `.duplicateItem`. To update existing values,
    /// use `update(...)` instead.
    ///
    /// ```swift
    /// struct Credentials: Codable {
    ///     let username: String
    ///     let password: String
    /// }
    ///
    /// let credentials = Credentials(username: "user", password: "pass")
    ///
    /// try keychain.save(
    ///     credentials,
    ///     for: "user_credentials",
    ///     with: .genericPassword,
    ///     accessibility: nil,
    ///     isSynchronizable: nil
    /// )
    /// ```
    ///
    /// - Parameters:
    ///   - value: A Codable value to encode and store.
    ///   - key: A string key to identify the stored item.
    ///   - type: The Keychain item class (e.g. `.genericPassword`, `.internetPassword`).
    ///   - accessibility: Optional override for access control.
    ///   - isSynchronizable: Optional override for iCloud sync.
    /// - Throws: `.duplicateItem` if the key already exists.
    public func save<T: Encodable>(
        _ value: T,
        for key: String,
        with type: KeychainItemClass,
        accessibility: KeychainAccessibility?,
        isSynchronizable: Bool?
    ) throws(KeychainError) {
        do {
            let data = try encoder.encode(value)
            try save(data, for: key, with: type, accessibility: accessibility, isSynchronizable: isSynchronizable)
        } catch let error as KeychainError {
            throw error
        } catch {
            throw KeychainError.invalidData
        }
    }
    
    /// Save raw Data to the Keychain.
    ///
    /// This method does **not overwrite** existing entries.
    /// It throws `.duplicateItem` if an item with the same `key` and `type` already exists.
    /// Use `update(...)` to modify existing values.
    ///
    /// ```swift
    /// let token = Data("secret".utf8)
    /// try keychain.save(
    ///     token,
    ///     for: "auth_token",
    ///     with: .genericPassword,
    ///     accessibility: nil,
    ///     isSynchronizable: nil
    /// )
    /// ```
    ///
    /// - Parameters:
    ///   - value: Data to store.
    ///   - key: A unique string key.
    ///   - type: The Keychain item class.
    ///   - accessibility: Optional access control override.
    ///   - isSynchronizable: Optional iCloud sync flag.
    /// - Throws: `.duplicateItem` if the key already exists.
    public func save(
        _ value: Data,
        for key: String,
        with type: KeychainItemClass,
        accessibility: KeychainAccessibility? = nil,
        isSynchronizable: Bool? = nil
    ) throws(KeychainError) {
        try KeychainRuntime.shared.backend.save(
            value,
            for: key,
            type: type,
            accessible: accessibility ?? self.accessibility,
            synchronizable: isSynchronizable ?? self.isSynchronizable,
            service: service
        )
    }
    
    /// Load raw Data from the Keychain.
    ///
    /// ```swift
    /// let data = try keychain.load(for: "auth_token", with: .genericPassword)
    /// ```
    ///
    /// - Parameters:
    ///   - key: The unique key associated with the item.
    ///   - type: The Keychain item class.
    /// - Returns: Stored data for the given key.
    /// - Throws: `KeychainError` if the item is not found or decoding fails.
    public func load(
        for key: String,
        with type: KeychainItemClass
    ) throws(KeychainError) -> Data {
        guard let data = try KeychainRuntime.shared.backend.load(
            for: key,
            type: type,
            service: service
        ) else {
            throw KeychainError.itemNotFound
        }
        return data
    }
    
    /// Load and decode a Codable value from the Keychain.
    ///
    /// ```swift
    /// struct Credentials: Codable {
    ///     let username: String
    ///     let password: String
    /// }
    ///
    /// let credentials: Credentials = try keychain.load(
    ///     for: "user_credentials",
    ///     with: .genericPassword
    /// )
    /// ```
    ///
    /// - Parameters:
    ///   - key: Key used to store the Codable value.
    ///   - type: The Keychain item class.
    /// - Returns: A decoded value of the expected Codable type.
    /// - Throws: `KeychainError` on failure; `.decodeFailure` if the stored data cannot be decoded as `T`.
    public func load<T: Decodable>(
        for key: String,
        with type: KeychainItemClass
    ) throws(KeychainError) -> T {
        let data = try load(for: key, with: type)
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw KeychainError.decodeFailure
        }
    }
    
    /// Update an existing Keychain item with new Data.
    ///
    /// ```swift
    /// try keychain.update(Data("newtoken".utf8), for: "auth_token", with: .genericPassword)
    /// ```
    ///
    /// - Parameters:
    ///   - value: New Data to replace the existing item.
    ///   - key: Existing Keychain key.
    ///   - type: The Keychain item class.
    ///   - accessibility: When provided, the item's accessibility is re-applied alongside
    ///     the new value. Pass `nil` (the default) to leave the stored accessibility unchanged.
    /// - Throws: `KeychainError` on failure.
    public func update(
        _ value: Data,
        for key: String,
        with type: KeychainItemClass,
        accessibility: KeychainAccessibility? = nil
    ) throws(KeychainError) {
        try KeychainRuntime.shared.backend.update(
            value,
            for: key,
            type: type,
            accessible: accessibility,
            service: service
        )
    }
    
    /// Update a Codable value already stored in the Keychain.
    ///
    /// ```swift
    /// let updatedCredentials = Credentials(username: "user", password: "newpass")
    /// try keychain.update(updatedCredentials, for: "user_credentials", with: .genericPassword)
    /// ```
    ///
    /// - Parameters:
    ///   - value: A Codable value to encode and update.
    ///   - key: Existing Keychain key.
    ///   - type: The Keychain item class.
    ///   - accessibility: When provided, the item's accessibility is re-applied alongside
    ///     the new value. Pass `nil` (the default) to leave the stored accessibility unchanged.
    /// - Throws: `KeychainError` if the item doesn't exist or encoding fails.
    public func update<T: Encodable>(
        _ value: T,
        for key: String,
        with type: KeychainItemClass,
        accessibility: KeychainAccessibility? = nil
    ) throws(KeychainError) {
        do {
            let data = try encoder.encode(value)
            try update(data, for: key, with: type, accessibility: accessibility)
        } catch let error as KeychainError {
            throw error
        } catch {
            throw KeychainError.invalidData
        }
    }
    
    /// Delete a Keychain item.
    ///
    /// ```swift
    /// try keychain.delete(for: "auth_token", with: .genericPassword)
    /// ```
    ///
    /// - Parameters:
    ///   - key: The key to identify the item.
    ///   - type: The Keychain item class.
    /// - Throws: `KeychainError` if the item cannot be found or deletion fails.
    public func delete(
        for key: String,
        with type: KeychainItemClass
    ) throws(KeychainError) {
        try KeychainRuntime.shared.backend.delete(
            for: key,
            type: type,
            service: service
        )
    }
}
