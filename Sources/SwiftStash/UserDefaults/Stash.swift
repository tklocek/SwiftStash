//
//  Stash.swift
//  SwiftStash
//
// Copyright (c) 2026 SwiftStash contributors
// SPDX-License-Identifier: MIT
//

import Foundation

/// A property wrapper for type-safe UserDefaults access with logging support.
///
/// SwiftStash provides a simple, type-safe way to store values in UserDefaults
/// with built-in logging capabilities for debugging and monitoring.
///
/// ## Quick Start
///
/// ```swift
/// // 1. Configure at app launch (optional)
/// SwiftStash.configureLogging(level: .normal)
/// SwiftStash.configureUserDefaults(suiteName: "group.com.example.app")
///
/// // 2. Use @Stash property wrapper
/// @Stash(key: "username", defaultValue: "")
/// var username: String
///
/// // 3. Use it like any normal property
/// username = "john_doe"
/// print(username)  // "john_doe"
/// ```
///
/// ## Usage Examples
///
/// ```swift
/// // Primitive types with default values
/// @Stash(key: "username", defaultValue: "")
/// var username: String
///
/// @Stash(key: "loginCount", defaultValue: 0)
/// var loginCount: Int
///
/// // Codable types
/// @Stash(codable: "user", defaultValue: User())
/// var user: User
///
/// // Optional values (no default needed)
/// @Stash(key: "lastLogin")
/// var lastLogin: Date?
///
/// @Stash(codable: "settings")
/// var settings: AppSettings?
///
/// // Override the global UserDefaults for a specific property
/// @Stash(key: "localOnly", defaultValue: "", userDefaults: .standard)
/// var localOnly: String
/// ```
@propertyWrapper
public struct Stash<Value: Sendable>: Sendable {
    private let storage: AnyUserDefaultsStorage<Value>
    
    public var wrappedValue: Value {
        get { storage.get() }
        nonmutating set { storage.set(newValue) }
    }

    /// A handle for key existence checks, removal, and change observation.
    ///
    /// ```swift
    /// @Stash(key: "launchCount", defaultValue: 0)
    /// var launchCount: Int
    ///
    /// if !$launchCount.exists { ... }   // nothing stored yet
    /// $launchCount.remove()             // reads fall back to the default
    /// ```
    public var projectedValue: StashHandle<Value> {
        StashHandle(storage: storage)
    }


    // MARK: - Primitive
    
    /// Creates a property wrapper for storing primitive values in UserDefaults.
    /// - Parameters:
    ///   - key: The key to store the value under in UserDefaults.
    ///   - defaultValue: The default value to return if no value is stored.
    ///   - userDefaults: The UserDefaults instance to use. Defaults to the globally configured instance.
    public init(
        key: String,
        defaultValue: Value,
        userDefaults: UserDefaults? = nil
    ) where Value: UserDefaultsPrimitiveType {
        let resolvedDefaults = userDefaults ?? StashConfiguration.shared.userDefaults
        self.storage = AnyUserDefaultsStorage(
            PrimitiveUserDefaultsStorage(
                key: key,
                defaultValue: defaultValue,
                userDefaults: resolvedDefaults
            )
        )
    }

    /// Creates a property wrapper for storing primitive values in UserDefaults
    /// using `@AppStorage`-style syntax.
    /// - Parameters:
    ///   - wrappedValue: The default value to return if no value is stored.
    ///   - key: The key to store the value under in UserDefaults.
    ///   - userDefaults: The UserDefaults instance to use. Defaults to the globally configured instance.
    public init(
        wrappedValue: Value,
        _ key: String,
        userDefaults: UserDefaults? = nil
    ) where Value: UserDefaultsPrimitiveType {
        self.init(key: key, defaultValue: wrappedValue, userDefaults: userDefaults)
    }
}

// MARK: - Optional primitives

public extension Stash where Value: ExpressibleByNilLiteral & UserDefaultsPrimitiveType {
    /// Creates a property wrapper for storing optional primitive values in UserDefaults.
    /// - Parameters:
    ///   - key: The key to store the value under in UserDefaults.
    ///   - userDefaults: The UserDefaults instance to use. Defaults to the globally configured instance.
    init(
        key: String,
        userDefaults: UserDefaults? = nil
    ) {
        self.init(key: key, defaultValue: nil, userDefaults: userDefaults)
    }

    /// Creates a property wrapper for storing optional primitive values in UserDefaults
    /// using `@AppStorage`-style syntax.
    /// - Parameters:
    ///   - key: The key to store the value under in UserDefaults.
    ///   - userDefaults: The UserDefaults instance to use. Defaults to the globally configured instance.
    init(
        _ key: String,
        userDefaults: UserDefaults? = nil
    ) {
        self.init(key: key, userDefaults: userDefaults)
    }
}

// MARK: - Codable

public extension Stash where Value: Codable {
    /// Creates a property wrapper for storing Codable types in UserDefaults using JSON encoding.
    /// - Parameters:
    ///   - key: The key to store the value under in UserDefaults.
    ///   - defaultValue: The default value to return if no value is stored or decoding fails.
    ///   - userDefaults: The UserDefaults instance to use. Defaults to the globally configured instance.
    ///   - encoder: Custom JSON encoder (defaults to a standard `JSONEncoder`). Configure it
    ///     fully before passing it in; the wrapper keeps using this instance, so it must not
    ///     be mutated afterwards.
    ///   - decoder: Custom JSON decoder (defaults to a standard `JSONDecoder`). The same rule
    ///     applies: configure before passing, never mutate afterwards.
    init(
        codable key: String,
        defaultValue: Value,
        userDefaults: UserDefaults? = nil,
        encoder: JSONEncoder? = nil,
        decoder: JSONDecoder? = nil
    ) {
        let resolvedDefaults = userDefaults ?? StashConfiguration.shared.userDefaults
        self.storage = AnyUserDefaultsStorage(
            CodableUserDefaultsStorage(
                key: key,
                defaultValue: defaultValue,
                userDefaults: resolvedDefaults,
                encoder: encoder ?? JSONEncoder(),
                decoder: decoder ?? JSONDecoder()
            )
        )
    }

    /// Creates a property wrapper for storing Codable types in UserDefaults using JSON encoding
    /// with `@AppStorage`-style syntax.
    /// - Parameters:
    ///   - wrappedValue: The default value to return if no value is stored or decoding fails.
    ///   - key: The key to store the value under in UserDefaults.
    ///   - userDefaults: The UserDefaults instance to use. Defaults to the globally configured instance.
    ///   - encoder: Custom JSON encoder (defaults to a standard `JSONEncoder`). Configure it
    ///     fully before passing it in; the wrapper keeps using this instance, so it must not
    ///     be mutated afterwards.
    ///   - decoder: Custom JSON decoder (defaults to a standard `JSONDecoder`). The same rule
    ///     applies: configure before passing, never mutate afterwards.
    init(
        wrappedValue: Value,
        codable key: String,
        userDefaults: UserDefaults? = nil,
        encoder: JSONEncoder? = nil,
        decoder: JSONDecoder? = nil
    ) {
        self.init(codable: key, defaultValue: wrappedValue, userDefaults: userDefaults, encoder: encoder, decoder: decoder)
    }
}

// MARK: - Optional codables

public extension Stash where Value: Codable & ExpressibleByNilLiteral {
    /// Creates a property wrapper for storing optional Codable types in UserDefaults using JSON encoding.
    /// - Parameters:
    ///   - key: The key to store the value under in UserDefaults.
    ///   - userDefaults: The UserDefaults instance to use. Defaults to the globally configured instance.
    ///   - encoder: Custom JSON encoder (defaults to a standard `JSONEncoder`). Configure it
    ///     fully before passing it in; the wrapper keeps using this instance, so it must not
    ///     be mutated afterwards.
    ///   - decoder: Custom JSON decoder (defaults to a standard `JSONDecoder`). The same rule
    ///     applies: configure before passing, never mutate afterwards.
    init(
        codable key: String,
        userDefaults: UserDefaults? = nil,
        encoder: JSONEncoder? = nil,
        decoder: JSONDecoder? = nil
    ) {
        self.init(codable: key, defaultValue: nil, userDefaults: userDefaults, encoder: encoder, decoder: decoder)
    }
}

// MARK: - RawRepresentable (Enums)

public extension Stash where Value: RawRepresentable, Value.RawValue: PropertyListNativeType {
    /// Creates a property wrapper for storing RawRepresentable types (like enums) in UserDefaults.
    /// The raw value is stored directly, making it compatible with UserDefaults property list types.
    /// - Parameters:
    ///   - key: The key to store the value under in UserDefaults.
    ///   - defaultValue: The default value to return if no value is stored or conversion fails.
    ///   - userDefaults: The UserDefaults instance to use. Defaults to the globally configured instance.
    init(
        key: String,
        defaultValue: Value,
        userDefaults: UserDefaults? = nil
    ) {
        let resolvedDefaults = userDefaults ?? StashConfiguration.shared.userDefaults
        self.storage = AnyUserDefaultsStorage(
            RawRepresentableUserDefaultsStorage(
                key: key,
                defaultValue: defaultValue,
                userDefaults: resolvedDefaults
            )
        )
    }

    /// Creates a property wrapper for storing RawRepresentable types (like enums) in UserDefaults
    /// using `@AppStorage`-style syntax.
    /// - Parameters:
    ///   - wrappedValue: The default value to return if no value is stored or conversion fails.
    ///   - key: The key to store the value under in UserDefaults.
    ///   - userDefaults: The UserDefaults instance to use. Defaults to the globally configured instance.
    init(
        wrappedValue: Value,
        _ key: String,
        userDefaults: UserDefaults? = nil
    ) {
        self.init(key: key, defaultValue: wrappedValue, userDefaults: userDefaults)
    }
}

// MARK: - Optional RawRepresentable

public extension Stash {
    /// Creates a property wrapper for storing optional RawRepresentable types in UserDefaults.
    /// - Parameters:
    ///   - key: The key to store the value under in UserDefaults.
    ///   - userDefaults: The UserDefaults instance to use. Defaults to the globally configured instance.
    init<Wrapped>(
        key: String,
        userDefaults: UserDefaults? = nil
    ) where Value == Wrapped?, Wrapped: RawRepresentable, Wrapped.RawValue: PropertyListNativeType {
        let resolvedDefaults = userDefaults ?? StashConfiguration.shared.userDefaults
        self.storage = AnyUserDefaultsStorage(
            OptionalRawRepresentableUserDefaultsStorage<Wrapped>(
                key: key,
                userDefaults: resolvedDefaults
            )
        )
    }

    /// Creates a property wrapper for storing optional RawRepresentable types in UserDefaults
    /// using `@AppStorage`-style syntax.
    /// - Parameters:
    ///   - key: The key to store the value under in UserDefaults.
    ///   - userDefaults: The UserDefaults instance to use. Defaults to the globally configured instance.
    init<Wrapped>(
        _ key: String,
        userDefaults: UserDefaults? = nil
    ) where Value == Wrapped?, Wrapped: RawRepresentable, Wrapped.RawValue: PropertyListNativeType {
        self.init(key: key, userDefaults: userDefaults)
    }
}
