//
//  Stashed+CustomKeys.swift
//  SwiftStash
//
// Copyright (c) 2026 SwiftStash contributors
// SPDX-License-Identifier: MIT
//

import Foundation
import SwiftStash

// MARK: - Primitive

public extension Stashed {
    /// Creates a SwiftUI-aware property wrapper for primitive values in UserDefaults,
    /// using a string-backed key type (e.g. `enum SettingsKey: String`).
    /// - Parameters:
    ///   - key: The key to store the value under; its `rawValue` is used as the UserDefaults key.
    ///   - defaultValue: The default value to return if no value is stored.
    ///   - store: The UserDefaults instance to use. Defaults to the globally configured instance.
    init(
        key: some RawRepresentable<String>,
        defaultValue: Value,
        store: UserDefaults? = nil
    ) where Value: UserDefaultsPrimitiveType {
        self.init(key: key.rawValue, defaultValue: defaultValue, store: store)
    }

    /// Creates a SwiftUI-aware property wrapper for primitive values in UserDefaults
    /// using `@AppStorage`-style syntax with a string-backed key type.
    /// - Parameters:
    ///   - wrappedValue: The default value to return if no value is stored.
    ///   - key: The key to store the value under; its `rawValue` is used as the UserDefaults key.
    ///   - store: The UserDefaults instance to use. Defaults to the globally configured instance.
    init(
        wrappedValue: Value,
        _ key: some RawRepresentable<String>,
        store: UserDefaults? = nil
    ) where Value: UserDefaultsPrimitiveType {
        self.init(key: key.rawValue, defaultValue: wrappedValue, store: store)
    }
}

// MARK: - Optional primitives

public extension Stashed where Value: ExpressibleByNilLiteral & UserDefaultsPrimitiveType {
    /// Creates a SwiftUI-aware property wrapper for optional primitive values in UserDefaults,
    /// using a string-backed key type.
    /// - Parameters:
    ///   - key: The key to store the value under; its `rawValue` is used as the UserDefaults key.
    ///   - store: The UserDefaults instance to use. Defaults to the globally configured instance.
    init(
        key: some RawRepresentable<String>,
        store: UserDefaults? = nil
    ) {
        self.init(key: key.rawValue, store: store)
    }

    /// Creates a SwiftUI-aware property wrapper for optional primitive values in UserDefaults
    /// using `@AppStorage`-style syntax with a string-backed key type.
    /// - Parameters:
    ///   - key: The key to store the value under; its `rawValue` is used as the UserDefaults key.
    ///   - store: The UserDefaults instance to use. Defaults to the globally configured instance.
    init(
        _ key: some RawRepresentable<String>,
        store: UserDefaults? = nil
    ) {
        self.init(key: key.rawValue, store: store)
    }
}

// MARK: - Codable

public extension Stashed where Value: Codable {
    /// Creates a SwiftUI-aware property wrapper for Codable values in UserDefaults using JSON encoding,
    /// using a string-backed key type.
    /// - Parameters:
    ///   - key: The key to store the value under; its `rawValue` is used as the UserDefaults key.
    ///   - defaultValue: The default value to return if no value is stored or decoding fails.
    ///   - store: The UserDefaults instance to use. Defaults to the globally configured instance.
    ///   - encoder: Custom JSON encoder (defaults to a standard `JSONEncoder`). Configure it
    ///     fully before passing it in; the wrapper keeps using this instance, so it must not
    ///     be mutated afterwards.
    ///   - decoder: Custom JSON decoder (defaults to a standard `JSONDecoder`). The same rule
    ///     applies: configure before passing, never mutate afterwards.
    init(
        codable key: some RawRepresentable<String>,
        defaultValue: Value,
        store: UserDefaults? = nil,
        encoder: JSONEncoder? = nil,
        decoder: JSONDecoder? = nil
    ) {
        self.init(codable: key.rawValue, defaultValue: defaultValue, store: store, encoder: encoder, decoder: decoder)
    }

    /// Creates a SwiftUI-aware property wrapper for Codable values in UserDefaults using JSON encoding
    /// with `@AppStorage`-style syntax and a string-backed key type.
    /// - Parameters:
    ///   - wrappedValue: The default value to return if no value is stored or decoding fails.
    ///   - key: The key to store the value under; its `rawValue` is used as the UserDefaults key.
    ///   - store: The UserDefaults instance to use. Defaults to the globally configured instance.
    ///   - encoder: Custom JSON encoder (defaults to a standard `JSONEncoder`). Configure it
    ///     fully before passing it in; the wrapper keeps using this instance, so it must not
    ///     be mutated afterwards.
    ///   - decoder: Custom JSON decoder (defaults to a standard `JSONDecoder`). The same rule
    ///     applies: configure before passing, never mutate afterwards.
    init(
        wrappedValue: Value,
        codable key: some RawRepresentable<String>,
        store: UserDefaults? = nil,
        encoder: JSONEncoder? = nil,
        decoder: JSONDecoder? = nil
    ) {
        self.init(codable: key.rawValue, defaultValue: wrappedValue, store: store, encoder: encoder, decoder: decoder)
    }
}

// MARK: - Optional codables

public extension Stashed where Value: Codable & ExpressibleByNilLiteral {
    /// Creates a SwiftUI-aware property wrapper for optional Codable values in UserDefaults
    /// using JSON encoding, using a string-backed key type.
    /// - Parameters:
    ///   - key: The key to store the value under; its `rawValue` is used as the UserDefaults key.
    ///   - store: The UserDefaults instance to use. Defaults to the globally configured instance.
    ///   - encoder: Custom JSON encoder (defaults to a standard `JSONEncoder`). Configure it
    ///     fully before passing it in; the wrapper keeps using this instance, so it must not
    ///     be mutated afterwards.
    ///   - decoder: Custom JSON decoder (defaults to a standard `JSONDecoder`). The same rule
    ///     applies: configure before passing, never mutate afterwards.
    init(
        codable key: some RawRepresentable<String>,
        store: UserDefaults? = nil,
        encoder: JSONEncoder? = nil,
        decoder: JSONDecoder? = nil
    ) {
        self.init(codable: key.rawValue, store: store, encoder: encoder, decoder: decoder)
    }
}

// MARK: - RawRepresentable (Enums)

public extension Stashed where Value: RawRepresentable, Value.RawValue: PropertyListNativeType {
    /// Creates a SwiftUI-aware property wrapper for RawRepresentable values (like enums) in UserDefaults,
    /// using a string-backed key type.
    /// - Parameters:
    ///   - key: The key to store the value under; its `rawValue` is used as the UserDefaults key.
    ///   - defaultValue: The default value to return if no value is stored or conversion fails.
    ///   - store: The UserDefaults instance to use. Defaults to the globally configured instance.
    init(
        key: some RawRepresentable<String>,
        defaultValue: Value,
        store: UserDefaults? = nil
    ) {
        self.init(key: key.rawValue, defaultValue: defaultValue, store: store)
    }

    /// Creates a SwiftUI-aware property wrapper for RawRepresentable values (like enums) in UserDefaults
    /// using `@AppStorage`-style syntax with a string-backed key type.
    /// - Parameters:
    ///   - wrappedValue: The default value to return if no value is stored or conversion fails.
    ///   - key: The key to store the value under; its `rawValue` is used as the UserDefaults key.
    ///   - store: The UserDefaults instance to use. Defaults to the globally configured instance.
    init(
        wrappedValue: Value,
        _ key: some RawRepresentable<String>,
        store: UserDefaults? = nil
    ) {
        self.init(key: key.rawValue, defaultValue: wrappedValue, store: store)
    }
}

// MARK: - Optional RawRepresentable

public extension Stashed {
    /// Creates a SwiftUI-aware property wrapper for optional RawRepresentable values in UserDefaults,
    /// using a string-backed key type.
    /// - Parameters:
    ///   - key: The key to store the value under; its `rawValue` is used as the UserDefaults key.
    ///   - store: The UserDefaults instance to use. Defaults to the globally configured instance.
    init<Wrapped>(
        key: some RawRepresentable<String>,
        store: UserDefaults? = nil
    ) where Value == Wrapped?, Wrapped: RawRepresentable, Wrapped.RawValue: PropertyListNativeType {
        self.init(key: key.rawValue, store: store)
    }

    /// Creates a SwiftUI-aware property wrapper for optional RawRepresentable values in UserDefaults
    /// using `@AppStorage`-style syntax with a string-backed key type.
    /// - Parameters:
    ///   - key: The key to store the value under; its `rawValue` is used as the UserDefaults key.
    ///   - store: The UserDefaults instance to use. Defaults to the globally configured instance.
    init<Wrapped>(
        _ key: some RawRepresentable<String>,
        store: UserDefaults? = nil
    ) where Value == Wrapped?, Wrapped: RawRepresentable, Wrapped.RawValue: PropertyListNativeType {
        self.init(key: key.rawValue, store: store)
    }
}
