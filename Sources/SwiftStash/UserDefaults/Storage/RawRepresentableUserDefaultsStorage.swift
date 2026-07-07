//
//  RawRepresentableUserDefaultsStorage.swift
//  SwiftStash
//
// Copyright (c) 2026 SwiftStash contributors
// SPDX-License-Identifier: MIT
//

import Foundation

/// Storage implementation for RawRepresentable types (like enums).
/// Stores the raw value directly in UserDefaults.
package struct RawRepresentableUserDefaultsStorage<Value: RawRepresentable>: UserDefaultsStorage where Value.RawValue: PropertyListNativeType {
    package typealias StoredValue = Value

    package let key: String
    package let store: UserDefaults
    private let defaultValue: Value

    package init(key: String, defaultValue: Value, userDefaults: UserDefaults) {
        self.key = key
        self.defaultValue = defaultValue
        self.store = userDefaults
    }

    package func get() -> Value {
        let typeName = String(describing: Value.self)
        let object = store.object(forKey: key)

        guard let rawValue = object as? Value.RawValue,
              let value = Value(rawValue: rawValue) else {
            if object != nil {
                Logging.logOperation("GET (invalid raw value, using default)", key: key, type: typeName)
            } else {
                Logging.logOperation("GET (using default)", key: key, type: typeName)
            }
            return defaultValue
        }

        Logging.logOperation("GET", key: key, type: typeName)
        return value
    }

    package func set(_ newValue: Value) {
        let typeName = String(describing: Value.self)

        if let optional = newValue as? (any OptionalProtocol), optional.isNil {
            Logging.logOperation("REMOVE (nil value)", key: key, type: typeName)
            store.removeObject(forKey: key)
        } else {
            Logging.logOperation("SET", key: key, type: typeName)
            store.set(newValue.rawValue, forKey: key)
        }
    }
}

// `@unchecked` because `UserDefaults` is documented as thread-safe but not annotated
// `Sendable` in the SDK. All other stored properties are immutable `Sendable` values.
extension RawRepresentableUserDefaultsStorage: @unchecked Sendable where Value: Sendable {}

// MARK: - Optional RawRepresentable Storage

/// Storage implementation for optional RawRepresentable types.
package struct OptionalRawRepresentableUserDefaultsStorage<Wrapped: RawRepresentable>: UserDefaultsStorage where Wrapped.RawValue: PropertyListNativeType {
    package typealias StoredValue = Wrapped?

    package let key: String
    package let store: UserDefaults
    package init(key: String, userDefaults: UserDefaults) {
        self.key = key
        self.store = userDefaults
    }

    package func get() -> Wrapped? {
        let typeName = String(describing: Wrapped?.self)
        let object = store.object(forKey: key)

        guard let rawValue = object as? Wrapped.RawValue,
              let value = Wrapped(rawValue: rawValue) else {
            if object != nil {
                Logging.logOperation("GET (invalid raw value, returning nil)", key: key, type: typeName)
            } else {
                Logging.logOperation("GET (not set, returning nil)", key: key, type: typeName)
            }
            return nil
        }

        Logging.logOperation("GET", key: key, type: typeName)
        return value
    }

    package func set(_ newValue: Wrapped?) {
        let typeName = String(describing: Wrapped?.self)

        if let value = newValue {
            Logging.logOperation("SET", key: key, type: typeName)
            store.set(value.rawValue, forKey: key)
        } else {
            Logging.logOperation("REMOVE (nil value)", key: key, type: typeName)
            store.removeObject(forKey: key)
        }
    }
}

// `@unchecked` because `UserDefaults` is documented as thread-safe but not annotated
// `Sendable` in the SDK. The only other stored property is an immutable `String`.
extension OptionalRawRepresentableUserDefaultsStorage: @unchecked Sendable {}

