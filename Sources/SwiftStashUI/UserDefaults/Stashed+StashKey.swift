//
//  Stashed+StashKey.swift
//  SwiftStash
//
// Copyright (c) 2026 SwiftStash contributors
// SPDX-License-Identifier: MIT
//

import Foundation
import SwiftStash

public extension Stashed {
    /// Creates a SwiftUI-aware wrapper for a property-list primitive, using the key's name and
    /// default.
    ///
    /// ```swift
    /// @Stashed(.launchCount) private var launchCount: Int
    /// ```
    /// - Parameters:
    ///   - key: The key, carrying the UserDefaults key and the default value.
    ///   - store: The UserDefaults instance to use. Defaults to the environment's store,
    ///     else the store configured for the key's scope, else the globally configured instance.
    init(_ key: StashKey<Value>, store: UserDefaults? = nil) where Value: UserDefaultsPrimitiveType {
        self.init(key: key.name, defaultValue: key.defaultValue, store: store, scope: key.scope)
    }

    /// Creates a SwiftUI-aware wrapper for a raw-representable value (like an enum), using the
    /// key's name and default. The raw value is stored, as with `@AppStorage`.
    /// - Parameters:
    ///   - key: The key, carrying the UserDefaults key and the default value.
    ///   - store: The UserDefaults instance to use. Defaults to the environment's store,
    ///     else the store configured for the key's scope, else the globally configured instance.
    init(_ key: StashKey<Value>, store: UserDefaults? = nil)
    where Value: RawRepresentable, Value.RawValue: PropertyListNativeType {
        self.init(key: key.name, defaultValue: key.defaultValue, store: store, scope: key.scope)
    }

    /// Creates a SwiftUI-aware wrapper for an optional raw-representable value, using the key's
    /// name and default. Assigning `nil` removes the key.
    /// - Parameters:
    ///   - key: The key, carrying the UserDefaults key and the default value.
    ///   - store: The UserDefaults instance to use. Defaults to the environment's store,
    ///     else the store configured for the key's scope, else the globally configured instance.
    init<Wrapped>(_ key: StashKey<Value>, store: UserDefaults? = nil)
    where Value == Wrapped?, Wrapped: RawRepresentable, Wrapped.RawValue: PropertyListNativeType {
        self.init(key: key.name, defaultValue: key.defaultValue, store: store, scope: key.scope)
    }

    /// Creates a SwiftUI-aware wrapper for a `Codable` value stored as JSON, using the key's
    /// name and default.
    /// - Parameters:
    ///   - key: The key, carrying the UserDefaults key and the default value.
    ///   - store: The UserDefaults instance to use. Defaults to the environment's store,
    ///     else the store configured for the key's scope, else the globally configured instance.
    ///   - encoder: Custom JSON encoder (defaults to a standard `JSONEncoder`). Configure it
    ///     fully before passing it in; the wrapper keeps using this instance, so it must not
    ///     be mutated afterwards.
    ///   - decoder: Custom JSON decoder (defaults to a standard `JSONDecoder`). The same rule
    ///     applies: configure before passing, never mutate afterwards.
    init(
        codable key: StashKey<Value>,
        store: UserDefaults? = nil,
        encoder: JSONEncoder? = nil,
        decoder: JSONDecoder? = nil
    ) where Value: Codable {
        self.init(
            codable: key.name,
            defaultValue: key.defaultValue,
            store: store,
            scope: key.scope,
            encoder: encoder,
            decoder: decoder
        )
    }
}
