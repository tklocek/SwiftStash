//
//  SecureStashHelpers.swift
//  SwiftStash
//
// Copyright (c) 2026 SwiftStash contributors
// SPDX-License-Identifier: MIT
//

import Foundation

/// Utility methods for SecureStash batch operations and existence checks.
///
/// The `service` parameter namespaces `.genericPassword` items only. For
/// `.internetPassword`, items are identified by account + domain (carried by the
/// item class) and the service does not participate in the query.
public enum SecureStashHelpers {
    
    // MARK: - Batch Operations
    
    /// Deletes all Keychain items for a specific service identifier.
    ///
    /// **Use with caution!** This will delete ALL items associated with the service.
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Clear all app keychain data
    /// let deletedCount = SecureStashHelpers.clearAll(
    ///     service: "com.myapp",
    ///     itemClass: .genericPassword
    /// )
    /// print("Deleted \(deletedCount) items")
    /// ```
    ///
    /// Only `.genericPassword` and `.internetPassword` item classes are supported;
    /// other classes report `0` deleted items. Synchronizable and non-synchronizable
    /// items are both cleared.
    ///
    /// - Parameters:
    ///   - service: The service identifier
    ///   - itemClass: The keychain item class to clear (defaults to `.genericPassword`)
    /// - Returns: The number of deleted items.
    @discardableResult
    public static func clearAll(
        service: String,
        itemClass: KeychainItemClass = .genericPassword
    ) -> Int {
        KeychainRuntime.shared.backend.clearAll(service: service, itemClass: itemClass)
    }
    
    /// Checks if a Keychain item exists for the given key.
    ///
    /// ## Example
    ///
    /// ```swift
    /// if SecureStashHelpers.exists(
    ///     key: "authToken",
    ///     service: "com.myapp"
    /// ) {
    ///     print("Token exists")
    /// }
    /// ```
    ///
    /// Matches items regardless of their synchronizable state.
    ///
    /// - Parameters:
    ///   - key: The key to check
    ///   - service: The service identifier
    ///   - itemClass: The keychain item class
    /// - Returns: `true` if the item exists, `false` otherwise
    public static func exists(
        key: String,
        service: String,
        itemClass: KeychainItemClass = .genericPassword
    ) -> Bool {
        do {
            let data = try KeychainRuntime.shared.backend.load(
                for: key,
                type: itemClass,
                service: service
            )
            return data != nil
        } catch {
            return false
        }
    }
    
    /// Retrieves all keys stored in the Keychain for a specific service.
    ///
    /// Note: This only works for `.genericPassword` and `.internetPassword` item classes.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let keys = SecureStashHelpers.allKeys(
    ///     service: "com.myapp"
    /// )
    /// print("Stored keys: \(keys)")
    /// ```
    ///
    /// - Parameters:
    ///   - service: The service identifier
    ///   - itemClass: The keychain item class (defaults to `.genericPassword`)
    /// - Returns: Array of keys stored in the Keychain
    public static func allKeys(
        service: String,
        itemClass: KeychainItemClass = .genericPassword
    ) -> [String] {
        KeychainRuntime.shared.backend.allKeys(service: service, itemClass: itemClass)
    }
}
