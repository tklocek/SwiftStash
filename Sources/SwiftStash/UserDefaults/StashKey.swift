//
//  StashKey.swift
//  SwiftStash
//
// Copyright (c) 2026 SwiftStash contributors
// SPDX-License-Identifier: MIT
//

import Foundation

/// A UserDefaults key that carries its value type and its default.
///
/// A preference read by a model (`@Stash`) and shown in a view (`@Stashed`) states its default
/// twice with plain keys, and nothing checks that the two agree. A `StashKey` states it once:
/// every wrapper declared with the key reads the same default.
///
/// Declare each key as a static member of an extension of its value type; a call site then
/// names only the key and never writes a value:
///
/// ```swift
/// extension StashKey<Int> {
///     static var launchCount: Self { .init("launchCount", default: 0) }
/// }
///
/// extension StashKey<Date?> {
///     static var lastLogin: Self { .init("lastLogin") }        // optional: defaults to nil
/// }
///
/// @Stash(.launchCount) var launchCount: Int                    // in a model
/// @Stashed(.launchCount) private var launchCount: Int          // in a view, same default
/// ```
///
/// The storage format is chosen by the wrapper, as with plain keys: property-list primitives and
/// raw-representable enums use the unlabelled initialiser, any other `Codable` value uses
/// `codable:` (`@Stash(codable: .profile)`).
///
/// A key built from a string-backed key type takes that type's ``StashScope`` when the type is a
/// ``StashScopedKey``, so a package's keys resolve the package's store.
public struct StashKey<Value: Sendable>: Sendable {
    /// The UserDefaults key the value is stored under.
    public let name: String

    /// The value every wrapper declared with this key returns while nothing valid is stored.
    public let defaultValue: Value

    /// The scope declared by the key type this key was built from, if any.
    package let scope: StashScope?

    /// Creates a key with the given name and default.
    /// - Parameters:
    ///   - name: The UserDefaults key.
    ///   - defaultValue: The value returned while nothing valid is stored.
    public init(_ name: String, default defaultValue: Value) {
        self.name = name
        self.defaultValue = defaultValue
        self.scope = nil
    }

    /// Creates a key from a string-backed key type (e.g. `enum SettingsKey: String`).
    ///
    /// When the key type is a ``StashScopedKey``, wrappers declared with this key resolve the
    /// store of its ``StashScope``.
    /// - Parameters:
    ///   - key: The key; its `rawValue` is used as the UserDefaults key.
    ///   - defaultValue: The value returned while nothing valid is stored.
    public init(_ key: some RawRepresentable<String>, default defaultValue: Value) {
        self.name = key.rawValue
        self.defaultValue = defaultValue
        self.scope = StashScope.of(key)
    }
}

public extension StashKey where Value: ExpressibleByNilLiteral {
    /// Creates a key for an optional value that defaults to `nil`.
    /// - Parameter name: The UserDefaults key.
    init(_ name: String) {
        self.init(name, default: nil)
    }

    /// Creates a key for an optional value that defaults to `nil`, from a string-backed key type.
    /// - Parameter key: The key; its `rawValue` is used as the UserDefaults key.
    init(_ key: some RawRepresentable<String>) {
        self.init(key, default: nil)
    }
}

package extension StashKey {
    /// The explicit store if given, else the configured store of the key's scope;
    /// `nil` leaves the wrapper on the application-level store.
    func store(explicit userDefaults: UserDefaults?) -> UserDefaults? {
        userDefaults ?? scope.map { StashConfiguration.shared.resolveUserDefaults(for: $0) }
    }
}

// MARK: - Stash

public extension Stash {
    /// Creates a property wrapper for a property-list primitive, using the key's name and default.
    ///
    /// ```swift
    /// @Stash(.launchCount) var launchCount: Int
    /// ```
    /// - Parameters:
    ///   - key: The key, carrying the UserDefaults key and the default value.
    ///   - userDefaults: The UserDefaults instance to use. Defaults to the store configured for the
    ///     key's ``StashScope``, else the globally configured instance.
    init(_ key: StashKey<Value>, userDefaults: UserDefaults? = nil) where Value: UserDefaultsPrimitiveType {
        self.init(key: key.name, defaultValue: key.defaultValue, userDefaults: userDefaults, scope: key.scope)
    }

    /// Creates a property wrapper for a raw-representable value (like an enum), using the key's
    /// name and default. The raw value is stored, as with `@AppStorage`.
    /// - Parameters:
    ///   - key: The key, carrying the UserDefaults key and the default value.
    ///   - userDefaults: The UserDefaults instance to use. Defaults to the store configured for the
    ///     key's ``StashScope``, else the globally configured instance.
    init(_ key: StashKey<Value>, userDefaults: UserDefaults? = nil)
    where Value: RawRepresentable, Value.RawValue: PropertyListNativeType {
        self.init(key: key.name, defaultValue: key.defaultValue, userDefaults: userDefaults, scope: key.scope)
    }

    /// Creates a property wrapper for an optional raw-representable value, using the key's name
    /// and default. Assigning `nil` removes the key.
    /// - Parameters:
    ///   - key: The key, carrying the UserDefaults key and the default value.
    ///   - userDefaults: The UserDefaults instance to use. Defaults to the store configured for the
    ///     key's ``StashScope``, else the globally configured instance.
    init<Wrapped>(_ key: StashKey<Value>, userDefaults: UserDefaults? = nil)
    where Value == Wrapped?, Wrapped: RawRepresentable, Wrapped.RawValue: PropertyListNativeType {
        self.init(key: key.name, defaultValue: key.defaultValue, userDefaults: userDefaults, scope: key.scope)
    }

    /// Creates a property wrapper for a `Codable` value stored as JSON, using the key's name and
    /// default.
    ///
    /// ```swift
    /// @Stash(codable: .profile) var profile: Profile
    /// ```
    /// - Parameters:
    ///   - key: The key, carrying the UserDefaults key and the default value.
    ///   - userDefaults: The UserDefaults instance to use. Defaults to the store configured for the
    ///     key's ``StashScope``, else the globally configured instance.
    ///   - encoder: Custom JSON encoder (defaults to a standard `JSONEncoder`). Configure it
    ///     fully before passing it in; the wrapper keeps using this instance, so it must not
    ///     be mutated afterwards.
    ///   - decoder: Custom JSON decoder (defaults to a standard `JSONDecoder`). The same rule
    ///     applies: configure before passing, never mutate afterwards.
    init(
        codable key: StashKey<Value>,
        userDefaults: UserDefaults? = nil,
        encoder: JSONEncoder? = nil,
        decoder: JSONDecoder? = nil
    ) where Value: Codable {
        self.init(
            codable: key.name,
            defaultValue: key.defaultValue,
            userDefaults: userDefaults,
            scope: key.scope,
            encoder: encoder,
            decoder: decoder
        )
    }
}

// MARK: - Observation

public extension SwiftStash {
    /// An asynchronous stream that yields whenever the key's value changes.
    ///
    /// See ``updates(forKey:in:bufferingPolicy:)-swift.type.method`` for details.
    /// - Parameters:
    ///   - key: The key to observe.
    ///   - store: The UserDefaults instance to observe. Defaults to the store configured for the
    ///     key's ``StashScope``, else the globally configured instance.
    ///   - bufferingPolicy: How changes are buffered when they arrive faster than the consumer
    ///     iterates. Defaults to `.bufferingNewest(1)` (bursts coalesce into one pending signal).
    /// - Returns: A stream that yields once per change until the consuming task is cancelled.
    static func updates<Value>(
        forKey key: StashKey<Value>,
        in store: UserDefaults? = nil,
        bufferingPolicy: AsyncStream<Void>.Continuation.BufferingPolicy = .bufferingNewest(1)
    ) -> AsyncStream<Void> {
        updates(forKey: key.name, in: key.store(explicit: store), bufferingPolicy: bufferingPolicy)
    }
}
