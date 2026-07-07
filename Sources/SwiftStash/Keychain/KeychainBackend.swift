//
//  KeychainBackend.swift
//  SwiftStash
//
// Copyright (c) 2026 SwiftStash contributors
// SPDX-License-Identifier: MIT
//

import Foundation
import Security

protocol KeychainBackend: Sendable {
    func save(
        _ value: Data,
        for key: String,
        type: KeychainItemClass,
        accessible: KeychainAccessibility,
        synchronizable: Bool,
        service: String
    ) throws(KeychainError)

    /// Matches the item regardless of its synchronizable state. When `accessible` is
    /// non-`nil`, the item's accessibility is re-applied alongside the new value.
    func update(
        _ value: Data,
        for key: String,
        type: KeychainItemClass,
        accessible: KeychainAccessibility?,
        service: String
    ) throws(KeychainError)

    /// Matches the item regardless of its synchronizable state.
    func load(
        for key: String,
        type: KeychainItemClass,
        service: String
    ) throws(KeychainError) -> Data?

    /// Matches the item regardless of its synchronizable state.
    func delete(
        for key: String,
        type: KeychainItemClass,
        service: String
    ) throws(KeychainError)

    /// Deletes every matching item for the service and reports how many were removed.
    func clearAll(service: String, itemClass: KeychainItemClass) -> Int
    func allKeys(service: String, itemClass: KeychainItemClass) -> [String]
}

final class KeychainRuntime: @unchecked Sendable {
    static let shared = KeychainRuntime()

    private let lock = NSLock()
    private var runtimeBackend: any KeychainBackend = LiveKeychainBackend()

    private init() {}

    var backend: any KeychainBackend {
        lock.lock()
        defer { lock.unlock() }
        return runtimeBackend
    }

    func setBackend(_ backend: any KeychainBackend) {
        lock.lock()
        defer { lock.unlock() }
        runtimeBackend = backend
    }

    func resetBackend() {
        setBackend(LiveKeychainBackend())
    }
}

struct LiveKeychainBackend: KeychainBackend {
    func save(
        _ value: Data,
        for key: String,
        type: KeychainItemClass,
        accessible: KeychainAccessibility,
        synchronizable: Bool,
        service: String
    ) throws(KeychainError) {
        try SimpleKeychain.save(
            value,
            for: key,
            type: type,
            accessible: accessible,
            synchronizable: synchronizable,
            service: service
        )
    }

    func update(
        _ value: Data,
        for key: String,
        type: KeychainItemClass,
        accessible: KeychainAccessibility?,
        service: String
    ) throws(KeychainError) {
        try SimpleKeychain.update(
            value,
            for: key,
            type: type,
            accessible: accessible,
            service: service
        )
    }

    func load(
        for key: String,
        type: KeychainItemClass,
        service: String
    ) throws(KeychainError) -> Data? {
        try SimpleKeychain.load(
            for: key,
            type: type,
            service: service
        )
    }

    func delete(
        for key: String,
        type: KeychainItemClass,
        service: String
    ) throws(KeychainError) {
        try SimpleKeychain.delete(
            for: key,
            type: type,
            service: service
        )
    }

    func clearAll(service: String, itemClass: KeychainItemClass) -> Int {
        var query: [String: Any] = [
            kSecClass as String: itemClass.secValue,
            kSecAttrSynchronizable as String: kSecAttrSynchronizableAny,
            kSecUseDataProtectionKeychain as String: true
        ]

        switch itemClass {
        case .genericPassword:
            query[kSecAttrService as String] = service
        case .internetPassword(let domain):
            query[kSecAttrServer as String] = domain
        case .certificate, .key, .identity:
            Logging.logError("clearAll not supported for item class: \(itemClass)", storageType: .keychain)
            return 0
        }

        // SecItemDelete does not report how many items it removed, so count first.
        // Best effort: a concurrent write between the two calls can skew the count.
        let count = allKeys(service: service, itemClass: itemClass).count

        let status = SecItemDelete(query as CFDictionary)

        if status == errSecSuccess {
            Logging.logOperation("CLEAR ALL (deleted \(count))", key: service, itemClass: "\(itemClass)", storageType: .keychain)
            return count
        }

        if status == errSecItemNotFound {
            Logging.logOperation("CLEAR ALL (no items found)", key: service, itemClass: "\(itemClass)", storageType: .keychain)
            return 0
        }

        Logging.logError("CLEAR ALL failed: OSStatus \(status)", key: service, storageType: .keychain)
        return 0
    }

    func allKeys(service: String, itemClass: KeychainItemClass) -> [String] {
        var query: [String: Any] = [
            kSecClass as String: itemClass.secValue,
            kSecAttrSynchronizable as String: kSecAttrSynchronizableAny,
            kSecUseDataProtectionKeychain as String: true,
            kSecReturnAttributes as String: true,
            kSecMatchLimit as String: kSecMatchLimitAll
        ]

        switch itemClass {
        case .genericPassword:
            query[kSecAttrService as String] = service
        case .internetPassword(let domain):
            query[kSecAttrServer as String] = domain
        case .certificate, .key, .identity:
            Logging.logError("allKeys not supported for item class: \(itemClass)", storageType: .keychain)
            return []
        }

        var result: CFTypeRef?
        let status = unsafe SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let items = result as? [[String: Any]] else {
            if status != errSecItemNotFound {
                Logging.logError("allKeys failed: OSStatus \(status)", key: service, storageType: .keychain)
            }
            return []
        }

        let keys = items.compactMap { item -> String? in
            item[kSecAttrAccount as String] as? String
        }

        Logging.logOperation("ALL KEYS (found \(keys.count) keys)", key: service, itemClass: "\(itemClass)", storageType: .keychain)
        return keys
    }
}
