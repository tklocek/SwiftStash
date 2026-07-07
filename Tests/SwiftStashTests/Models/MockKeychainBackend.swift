//
//  MockKeychainBackend.swift
//  SwiftStash
//
// Copyright (c) 2026 SwiftStash contributors
// SPDX-License-Identifier: MIT
//

import Foundation
@testable import SwiftStash

private struct MockEntryKey: Hashable {
    let key: String
    let type: KeychainItemClass
    let synchronizable: Bool
    let service: String
}

private struct MockEntry {
    var data: Data
    /// Recorded so tests can assert accessibility propagation; `nil` for seeded
    /// items whose accessibility is deliberately unspecified.
    var accessible: KeychainAccessibility?
}

final class InMemoryKeychainBackend: @unchecked Sendable, KeychainBackend {
    private let lock = NSLock()
    private var entries: [MockEntryKey: MockEntry] = [:]

    /// Mirrors SecItem identity semantics: `service` (`kSecAttrService`) participates
    /// only for `.genericPassword`. Internet-password identity is account + server —
    /// the domain carried by the item class — and the live queries never set
    /// `kSecAttrService` for it, so the mock must not distinguish by it either.
    private func normalizedService(_ service: String, for type: KeychainItemClass) -> String {
        if case .internetPassword = type { return "" }
        return service
    }

    func seed(
        _ value: Data,
        for key: String,
        type: KeychainItemClass,
        synchronizable: Bool,
        service: String,
        accessible: KeychainAccessibility? = nil
    ) {
        lock.lock()
        defer { lock.unlock() }

        let entryKey = MockEntryKey(
            key: key,
            type: type,
            synchronizable: synchronizable,
            service: normalizedService(service, for: type)
        )
        entries[entryKey] = MockEntry(data: value, accessible: accessible)
    }

    /// The accessibility recorded for an item, or `nil` when the item is absent
    /// or was seeded without one.
    func accessibility(
        for key: String,
        type: KeychainItemClass,
        service: String
    ) -> KeychainAccessibility? {
        lock.lock()
        defer { lock.unlock() }

        return matchingKeys(for: key, type: type, service: service)
            .first
            .flatMap { entries[$0]?.accessible }
    }

    func save(
        _ value: Data,
        for key: String,
        type: KeychainItemClass,
        accessible: KeychainAccessibility,
        synchronizable: Bool,
        service: String
    ) throws(KeychainError) {
        lock.lock()
        defer { lock.unlock() }

        let entryKey = MockEntryKey(
            key: key,
            type: type,
            synchronizable: synchronizable,
            service: normalizedService(service, for: type)
        )
        guard entries[entryKey] == nil else {
            throw .duplicateItem
        }

        entries[entryKey] = MockEntry(data: value, accessible: accessible)
    }

    // Lookups match items regardless of their synchronizable state, mirroring the
    // kSecAttrSynchronizableAny semantics of the live backend.
    private func matchingKeys(for key: String, type: KeychainItemClass, service: String) -> [MockEntryKey] {
        let service = normalizedService(service, for: type)
        return entries.keys.filter { $0.key == key && $0.type == type && $0.service == service }
    }

    func update(
        _ value: Data,
        for key: String,
        type: KeychainItemClass,
        accessible: KeychainAccessibility?,
        service: String
    ) throws(KeychainError) {
        lock.lock()
        defer { lock.unlock() }

        let matches = matchingKeys(for: key, type: type, service: service)
        guard !matches.isEmpty else {
            throw .itemNotFound
        }

        for entryKey in matches {
            var entry = entries[entryKey] ?? MockEntry(data: value, accessible: nil)
            entry.data = value
            // Mirrors the live backend: a nil accessibility leaves the stored
            // attribute untouched; a non-nil one is re-applied with the write.
            if let accessible {
                entry.accessible = accessible
            }
            entries[entryKey] = entry
        }
    }

    func load(
        for key: String,
        type: KeychainItemClass,
        service: String
    ) throws(KeychainError) -> Data? {
        lock.lock()
        defer { lock.unlock() }

        return matchingKeys(for: key, type: type, service: service).first.flatMap { entries[$0]?.data }
    }

    func delete(
        for key: String,
        type: KeychainItemClass,
        service: String
    ) throws(KeychainError) {
        lock.lock()
        defer { lock.unlock() }

        for entryKey in matchingKeys(for: key, type: type, service: service) {
            entries.removeValue(forKey: entryKey)
        }
    }

    func clearAll(service: String, itemClass: KeychainItemClass) -> Int {
        lock.lock()
        defer { lock.unlock() }

        let service = normalizedService(service, for: itemClass)
        let keysToRemove = entries.keys.filter { entry in
            entry.service == service && entry.type == itemClass
        }

        for key in keysToRemove {
            entries.removeValue(forKey: key)
        }

        return keysToRemove.count
    }

    func allKeys(service: String, itemClass: KeychainItemClass) -> [String] {
        lock.lock()
        defer { lock.unlock() }

        switch itemClass {
        case .genericPassword, .internetPassword:
            let service = normalizedService(service, for: itemClass)
            let keys = entries.keys
                .filter { $0.service == service && $0.type == itemClass }
                .map(\.key)
            return Array(Set(keys))
        case .certificate, .key, .identity:
            return []
        }
    }
}
