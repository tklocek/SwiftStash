//
//  Stash+CustomKeys.swift
//  SwiftStash
//
// Copyright (c) 2026 SwiftStash contributors
// SPDX-License-Identifier: MIT
//

import Foundation

// MARK: - Primitive

public extension Stash {
    /// Creates a property wrapper for storing primitive values in UserDefaults,
    /// using a string-backed key type (e.g. `enum SettingsKey: String`).
    /// - Parameters:
    ///   - key: The key to store the value under; its `rawValue` is used as the UserDefaults key.
    ///   - defaultValue: The default value to return if no value is stored.
    ///   - userDefaults: The UserDefaults instance to use. Defaults to the globally configured instance.
    init(
        key: some RawRepresentable<String>,
        defaultValue: Value,
        userDefaults: UserDefaults? = nil
    ) where Value: UserDefaultsPrimitiveType {
        self.init(key: key.rawValue, defaultValue: defaultValue, userDefaults: userDefaults)
    }

    /// Creates a property wrapper for storing primitive values in UserDefaults
    /// using `@AppStorage`-style syntax with a string-backed key type.
    /// - Parameters:
    ///   - wrappedValue: The default value to return if no value is stored.
    ///   - key: The key to store the value under; its `rawValue` is used as the UserDefaults key.
    ///   - userDefaults: The UserDefaults instance to use. Defaults to the globally configured instance.
    init(
        wrappedValue: Value,
        _ key: some RawRepresentable<String>,
        userDefaults: UserDefaults? = nil
    ) where Value: UserDefaultsPrimitiveType {
        self.init(key: key.rawValue, defaultValue: wrappedValue, userDefaults: userDefaults)
    }
}

// MARK: - Optional primitives

public extension Stash where Value: ExpressibleByNilLiteral & UserDefaultsPrimitiveType {
    /// Creates a property wrapper for storing optional primitive values in UserDefaults,
    /// using a string-backed key type.
    /// - Parameters:
    ///   - key: The key to store the value under; its `rawValue` is used as the UserDefaults key.
    ///   - userDefaults: The UserDefaults instance to use. Defaults to the globally configured instance.
    init(
        key: some RawRepresentable<String>,
        userDefaults: UserDefaults? = nil
    ) {
        self.init(key: key.rawValue, userDefaults: userDefaults)
    }

    /// Creates a property wrapper for storing optional primitive values in UserDefaults
    /// using `@AppStorage`-style syntax with a string-backed key type.
    /// - Parameters:
    ///   - key: The key to store the value under; its `rawValue` is used as the UserDefaults key.
    ///   - userDefaults: The UserDefaults instance to use. Defaults to the globally configured instance.
    init(
        _ key: some RawRepresentable<String>,
        userDefaults: UserDefaults? = nil
    ) {
        self.init(key: key.rawValue, userDefaults: userDefaults)
    }
}

// MARK: - Codable

public extension Stash where Value: Codable {
    /// Creates a property wrapper for storing Codable types in UserDefaults using JSON encoding,
    /// using a string-backed key type.
    /// - Parameters:
    ///   - key: The key to store the value under; its `rawValue` is used as the UserDefaults key.
    ///   - defaultValue: The default value to return if no value is stored or decoding fails.
    ///   - userDefaults: The UserDefaults instance to use. Defaults to the globally configured instance.
    ///   - encoder: Custom JSON encoder (defaults to a standard `JSONEncoder`). Configure it
    ///     fully before passing it in; the wrapper keeps using this instance, so it must not
    ///     be mutated afterwards.
    ///   - decoder: Custom JSON decoder (defaults to a standard `JSONDecoder`). The same rule
    ///     applies: configure before passing, never mutate afterwards.
    init(
        codable key: some RawRepresentable<String>,
        defaultValue: Value,
        userDefaults: UserDefaults? = nil,
        encoder: JSONEncoder? = nil,
        decoder: JSONDecoder? = nil
    ) {
        self.init(codable: key.rawValue, defaultValue: defaultValue, userDefaults: userDefaults, encoder: encoder, decoder: decoder)
    }

    /// Creates a property wrapper for storing Codable types in UserDefaults using JSON encoding
    /// with `@AppStorage`-style syntax and a string-backed key type.
    /// - Parameters:
    ///   - wrappedValue: The default value to return if no value is stored or decoding fails.
    ///   - key: The key to store the value under; its `rawValue` is used as the UserDefaults key.
    ///   - userDefaults: The UserDefaults instance to use. Defaults to the globally configured instance.
    ///   - encoder: Custom JSON encoder (defaults to a standard `JSONEncoder`). Configure it
    ///     fully before passing it in; the wrapper keeps using this instance, so it must not
    ///     be mutated afterwards.
    ///   - decoder: Custom JSON decoder (defaults to a standard `JSONDecoder`). The same rule
    ///     applies: configure before passing, never mutate afterwards.
    init(
        wrappedValue: Value,
        codable key: some RawRepresentable<String>,
        userDefaults: UserDefaults? = nil,
        encoder: JSONEncoder? = nil,
        decoder: JSONDecoder? = nil
    ) {
        self.init(codable: key.rawValue, defaultValue: wrappedValue, userDefaults: userDefaults, encoder: encoder, decoder: decoder)
    }
}

// MARK: - Optional codables

public extension Stash where Value: Codable & ExpressibleByNilLiteral {
    /// Creates a property wrapper for storing optional Codable types in UserDefaults using JSON encoding,
    /// using a string-backed key type.
    /// - Parameters:
    ///   - key: The key to store the value under; its `rawValue` is used as the UserDefaults key.
    ///   - userDefaults: The UserDefaults instance to use. Defaults to the globally configured instance.
    ///   - encoder: Custom JSON encoder (defaults to a standard `JSONEncoder`). Configure it
    ///     fully before passing it in; the wrapper keeps using this instance, so it must not
    ///     be mutated afterwards.
    ///   - decoder: Custom JSON decoder (defaults to a standard `JSONDecoder`). The same rule
    ///     applies: configure before passing, never mutate afterwards.
    init(
        codable key: some RawRepresentable<String>,
        userDefaults: UserDefaults? = nil,
        encoder: JSONEncoder? = nil,
        decoder: JSONDecoder? = nil
    ) {
        self.init(codable: key.rawValue, userDefaults: userDefaults, encoder: encoder, decoder: decoder)
    }
}

// MARK: - RawRepresentable (Enums)

public extension Stash where Value: RawRepresentable, Value.RawValue: PropertyListNativeType {
    /// Creates a property wrapper for storing RawRepresentable types (like enums) in UserDefaults,
    /// using a string-backed key type.
    /// - Parameters:
    ///   - key: The key to store the value under; its `rawValue` is used as the UserDefaults key.
    ///   - defaultValue: The default value to return if no value is stored or conversion fails.
    ///   - userDefaults: The UserDefaults instance to use. Defaults to the globally configured instance.
    init(
        key: some RawRepresentable<String>,
        defaultValue: Value,
        userDefaults: UserDefaults? = nil
    ) {
        self.init(key: key.rawValue, defaultValue: defaultValue, userDefaults: userDefaults)
    }

    /// Creates a property wrapper for storing RawRepresentable types (like enums) in UserDefaults
    /// using `@AppStorage`-style syntax with a string-backed key type.
    /// - Parameters:
    ///   - wrappedValue: The default value to return if no value is stored or conversion fails.
    ///   - key: The key to store the value under; its `rawValue` is used as the UserDefaults key.
    ///   - userDefaults: The UserDefaults instance to use. Defaults to the globally configured instance.
    init(
        wrappedValue: Value,
        _ key: some RawRepresentable<String>,
        userDefaults: UserDefaults? = nil
    ) {
        self.init(key: key.rawValue, defaultValue: wrappedValue, userDefaults: userDefaults)
    }
}

// MARK: - Optional RawRepresentable

public extension Stash {
    /// Creates a property wrapper for storing optional RawRepresentable types in UserDefaults,
    /// using a string-backed key type.
    /// - Parameters:
    ///   - key: The key to store the value under; its `rawValue` is used as the UserDefaults key.
    ///   - userDefaults: The UserDefaults instance to use. Defaults to the globally configured instance.
    init<Wrapped>(
        key: some RawRepresentable<String>,
        userDefaults: UserDefaults? = nil
    ) where Value == Wrapped?, Wrapped: RawRepresentable, Wrapped.RawValue: PropertyListNativeType {
        self.init(key: key.rawValue, userDefaults: userDefaults)
    }

    /// Creates a property wrapper for storing optional RawRepresentable types in UserDefaults
    /// using `@AppStorage`-style syntax with a string-backed key type.
    /// - Parameters:
    ///   - key: The key to store the value under; its `rawValue` is used as the UserDefaults key.
    ///   - userDefaults: The UserDefaults instance to use. Defaults to the globally configured instance.
    init<Wrapped>(
        _ key: some RawRepresentable<String>,
        userDefaults: UserDefaults? = nil
    ) where Value == Wrapped?, Wrapped: RawRepresentable, Wrapped.RawValue: PropertyListNativeType {
        self.init(key: key.rawValue, userDefaults: userDefaults)
    }
}
