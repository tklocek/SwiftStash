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
    /// The storage on the store resolved at initialisation.
    private let storage: AnyUserDefaultsStorage<Value>
    /// Rebinds the storage to a ``StashContainer``'s store; `nil` when the declaration passed
    /// an explicit store, which a container never overrides.
    private let containerStorage: StashContainerStorage<Value>?
    
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

    /// Resolves the store and builds the storage for every initialiser.
    /// - Parameters:
    ///   - explicitStore: The store passed at the declaration, if any.
    ///   - scope: The key's scope, if its type declares one.
    ///   - makeStorage: Builds the storage on a given store.
    private init(
        explicitStore: UserDefaults?,
        scope: StashScope?,
        makeStorage: @escaping @Sendable (UserDefaults) -> AnyUserDefaultsStorage<Value>
    ) {
        let store = explicitStore ?? StashConfiguration.shared.resolveUserDefaults(for: scope)
        self.storage = makeStorage(store)
        self.containerStorage = explicitStore == nil ? StashContainerStorage(makeStorage) : nil
    }

    /// The storage on the container's store when `object` is a ``StashContainer`` and the
    /// declaration passed no explicit store; otherwise the storage resolved at initialisation.
    private func storage(in object: AnyObject) -> AnyUserDefaultsStorage<Value> {
        guard let containerStorage, let container = object as? any StashContainer else {
            return storage
        }
        return containerStorage.storage(on: container.stashStore.userDefaults)
    }

    // MARK: - Enclosing instance

    /// Reads and writes the property through its enclosing class instance.
    ///
    /// The compiler calls this for `@Stash` instance properties of classes, so a property of a
    /// ``StashContainer`` uses the container's store. In any other class it uses the store the
    /// wrapper resolved at initialisation, exactly as ``wrappedValue`` does.
    public static subscript<EnclosingSelf: AnyObject>(
        _enclosingInstance object: EnclosingSelf,
        wrapped wrappedKeyPath: ReferenceWritableKeyPath<EnclosingSelf, Value>,
        storage storageKeyPath: ReferenceWritableKeyPath<EnclosingSelf, Stash<Value>>
    ) -> Value {
        get { object[keyPath: storageKeyPath].storage(in: object).get() }
        set { object[keyPath: storageKeyPath].storage(in: object).set(newValue) }
    }

    /// The projected value of a `@Stash` instance property of a class, on the same store the
    /// property reads and writes (see ``subscript(_enclosingInstance:wrapped:storage:)``).
    public static subscript<EnclosingSelf: AnyObject>(
        _enclosingInstance object: EnclosingSelf,
        projected projectedKeyPath: KeyPath<EnclosingSelf, StashHandle<Value>>,
        storage storageKeyPath: ReferenceWritableKeyPath<EnclosingSelf, Stash<Value>>
    ) -> StashHandle<Value> {
        StashHandle(storage: object[keyPath: storageKeyPath].storage(in: object))
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
        self.init(key: key, defaultValue: defaultValue, userDefaults: userDefaults, scope: nil)
    }

    init(
        key: String,
        defaultValue: Value,
        userDefaults: UserDefaults?,
        scope: StashScope?
    ) where Value: UserDefaultsPrimitiveType {
        self.init(explicitStore: userDefaults, scope: scope) { store in
            AnyUserDefaultsStorage(
                PrimitiveUserDefaultsStorage(key: key, defaultValue: defaultValue, userDefaults: store)
            )
        }
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
        self.init(
            codable: key,
            defaultValue: defaultValue,
            userDefaults: userDefaults,
            scope: nil,
            encoder: encoder,
            decoder: decoder
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

extension Stash where Value: Codable {
    init(
        codable key: String,
        defaultValue: Value,
        userDefaults: UserDefaults?,
        scope: StashScope?,
        encoder: JSONEncoder?,
        decoder: JSONDecoder?
    ) {
        let encoder = encoder ?? JSONEncoder()
        let decoder = decoder ?? JSONDecoder()
        self.init(explicitStore: userDefaults, scope: scope) { store in
            AnyUserDefaultsStorage(
                CodableUserDefaultsStorage(
                    key: key,
                    defaultValue: defaultValue,
                    userDefaults: store,
                    encoder: encoder,
                    decoder: decoder
                )
            )
        }
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
        self.init(key: key, defaultValue: defaultValue, userDefaults: userDefaults, scope: nil)
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

extension Stash where Value: RawRepresentable, Value.RawValue: PropertyListNativeType {
    init(
        key: String,
        defaultValue: Value,
        userDefaults: UserDefaults?,
        scope: StashScope?
    ) {
        self.init(explicitStore: userDefaults, scope: scope) { store in
            AnyUserDefaultsStorage(
                RawRepresentableUserDefaultsStorage(key: key, defaultValue: defaultValue, userDefaults: store)
            )
        }
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
        self.init(key: key, defaultValue: nil, userDefaults: userDefaults, scope: nil)
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

extension Stash {
    init<Wrapped>(
        key: String,
        defaultValue: Value,
        userDefaults: UserDefaults?,
        scope: StashScope?
    ) where Value == Wrapped?, Wrapped: RawRepresentable, Wrapped.RawValue: PropertyListNativeType {
        self.init(explicitStore: userDefaults, scope: scope) { store in
            AnyUserDefaultsStorage(
                OptionalRawRepresentableUserDefaultsStorage<Wrapped>(
                    key: key,
                    userDefaults: store,
                    defaultValue: defaultValue
                )
            )
        }
    }
}
