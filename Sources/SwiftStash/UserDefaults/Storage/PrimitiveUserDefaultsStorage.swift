//
//  PrimitiveUserDefaultsStorage.swift
//  SwiftStash
//
// Copyright (c) 2026 SwiftStash contributors
// SPDX-License-Identifier: MIT
//

import Foundation

/// Storage implementation for primitive types that can be stored directly in UserDefaults.
/// Handles types like String, Int, Bool, Double, Date, Data, Arrays, and Dictionaries.
package struct PrimitiveUserDefaultsStorage<Value>: UserDefaultsStorage {
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

        guard object != nil else {
            Logging.logOperation("GET (using default)", key: key, type: typeName)
            return defaultValue
        }

        Logging.logOperation("GET", key: key, type: typeName)

        // URLs are archived by the dedicated setter below, so object(forKey:) returns
        // their archived Data; url(forKey:) is the matching read path.
        if Value.self == URL.self || Value.self == URL?.self {
            guard let url = store.url(forKey: key), let value = url as? Value else {
                return defaultValue
            }
            return value
        }

        return (object as? Value) ?? defaultValue
    }

    package func set(_ newValue: Value) {
        let typeName = String(describing: Value.self)

        if let optional = newValue as? (any OptionalProtocol), optional.isNil {
            Logging.logOperation("REMOVE (nil value)", key: key, type: typeName)
            store.removeObject(forKey: key)
        } else if let url = newValue as? URL {
            // URL is not a property-list type: the generic set(_: Any?, forKey:) rejects it
            // at runtime. The dedicated URL setter archives it the same way @AppStorage does.
            Logging.logOperation("SET", key: key, type: typeName)
            store.set(url, forKey: key)
        } else {
            Logging.logOperation("SET", key: key, type: typeName)
            store.set(newValue, forKey: key)
        }
    }

}

// `@unchecked` because `UserDefaults` is documented as thread-safe but not annotated
// `Sendable` in the SDK. All other stored properties are immutable `Sendable` values.
extension PrimitiveUserDefaultsStorage: @unchecked Sendable where Value: Sendable {}
