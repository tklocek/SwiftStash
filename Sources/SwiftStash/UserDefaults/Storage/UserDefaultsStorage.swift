//
//  UserDefaultsStorage.swift
//  SwiftStash
//
// Copyright (c) 2026 SwiftStash contributors
// SPDX-License-Identifier: MIT
//

import Foundation

// MARK: - Storage Protocol

/// Protocol defining the interface for UserDefaults storage operations.
/// Implementations handle different value types (primitives, Codable, RawRepresentable).
package protocol UserDefaultsStorage {
    associatedtype StoredValue
    var key: String { get }
    var store: UserDefaults { get }
    func get() -> StoredValue
    func set(_ newValue: StoredValue)
}

/// Type-erased wrapper for UserDefaultsStorage.
/// Allows storing any conforming storage implementation without exposing the concrete type.
///
/// `@unchecked` because `UserDefaults` is documented as thread-safe but not annotated
/// `Sendable` in the SDK. All other stored properties are immutable `Sendable` values.
package struct AnyUserDefaultsStorage<Value>: @unchecked Sendable {
    package let key: String
    package let store: UserDefaults
    private let _get: @Sendable () -> Value
    private let _set: @Sendable (Value) -> Void

    package init<S: UserDefaultsStorage & Sendable>(_ storage: S) where S.StoredValue == Value {
        self.key = storage.key
        self.store = storage.store
        self._get = { storage.get() }
        self._set = { storage.set($0) }
    }
    
    package func get() -> Value {
        _get()
    }
    
    package func set(_ newValue: Value) {
        _set(newValue)
    }
}
