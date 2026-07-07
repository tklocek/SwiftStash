//
//  CodableUserDefaultsStorage.swift
//  SwiftStash
//
// Copyright (c) 2026 SwiftStash contributors
// SPDX-License-Identifier: MIT
//

import Foundation

/// Storage implementation for Codable types using JSON encoding/decoding.
package struct CodableUserDefaultsStorage<Value: Codable>: UserDefaultsStorage {
    package typealias StoredValue = Value
    
    package let key: String
    package let store: UserDefaults
    private let defaultValue: Value
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    package init(
        key: String,
        defaultValue: Value,
        userDefaults: UserDefaults,
        encoder: JSONEncoder = JSONEncoder(),
        decoder: JSONDecoder = JSONDecoder()
    ) {
        self.key = key
        self.defaultValue = defaultValue
        self.store = userDefaults
        self.encoder = encoder
        self.decoder = decoder
    }
    
    package func get() -> Value {
        let typeName = String(describing: Value.self)
        
        guard let data = store.data(forKey: key) else {
            Logging.logOperation("GET (no data, using default)", key: key, type: typeName)
            return defaultValue
        }
        
        do {
            let decoded = try decoder.decode(Value.self, from: data)
            Logging.logCoding("Successfully decoded", key: key, type: typeName)
            Logging.logOperation("GET", key: key, type: typeName)
            return decoded
        } catch {
            Logging.logError(
                "Decoding failed: \(error.localizedDescription). Using default value.",
                key: key,
                type: typeName
            )
            return defaultValue
        }
    }
    
    package func set(_ newValue: Value) {
        let typeName = String(describing: Value.self)
        
        if let optional = newValue as? (any OptionalProtocol), optional.isNil {
            Logging.logOperation("REMOVE (nil value)", key: key, type: typeName)
            store.removeObject(forKey: key)
            return
        }
        
        do {
            let data = try encoder.encode(newValue)
            store.set(data, forKey: key)
            Logging.logCoding("Successfully encoded", key: key, type: typeName)
            Logging.logOperation("SET", key: key, type: typeName)
        } catch {
            // Keep whatever is already stored: deleting on a failed encode would
            // destroy the last known-good value over a transient error.
            Logging.logError(
                "Encoding failed: \(error.localizedDescription). Keeping previously stored value.",
                key: key,
                type: typeName
            )
        }
    }
}

// `@unchecked` only because of `UserDefaults`, which is documented as thread-safe but
// not annotated `Sendable` in the SDK. `JSONEncoder`/`JSONDecoder` are `Sendable` per
// the SDK (and must not be mutated after init — see the `encoder:`/`decoder:` parameter
// docs); all other stored properties are immutable `Sendable` values.
extension CodableUserDefaultsStorage: @unchecked Sendable where Value: Sendable {}
