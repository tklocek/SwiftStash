//
//  StashScope.swift
//  SwiftStash
//
// Copyright (c) 2026 SwiftStash contributors
// SPDX-License-Identifier: MIT
//

import Foundation

/// A named group of UserDefaults keys whose store can be configured independently
/// of the application-level store.
///
/// A package that uses SwiftStash internally declares its own scope and attaches it to its
/// key type through ``StashScopedKey``. Every wrapper declared with that key type resolves the
/// scope's store, so the package states its scope once per key type, not at every declaration:
///
/// ```swift
/// // In the package
/// extension StashScope {
///     static let tipJar = StashScope("TipJarKit")
/// }
///
/// enum TipJarKey: String, StashScopedKey {
///     case tipCount, lastTipDate
///     static var stashScope: StashScope { .tipJar }
/// }
///
/// @Stash(TipJarKey.tipCount) var tipCount = 0      // resolves the .tipJar store
/// ```
///
/// A scope nobody configured falls back to the application-level store, so adopting scopes
/// changes nothing until somebody configures one. The application may then move the
/// package's preferences without moving its own:
///
/// ```swift
/// // In the app
/// SwiftStash.configureUserDefaults(groupDefaults, for: .tipJar)
/// ```
///
/// - Important: A package configures only its own scope, never the application level.
///   ``SwiftStash/configureUserDefaults(_:)`` belongs to the application.
public struct StashScope: Hashable, Sendable {
    /// The identifier that distinguishes this scope from every other scope in the process.
    public let identifier: String

    /// Creates a scope with the given identifier.
    ///
    /// Use an identifier unique to the declaring package, such as its module name.
    /// - Parameter identifier: The scope identifier.
    public init(_ identifier: String) {
        self.identifier = identifier
    }
}

/// A string-backed key type whose keys belong to a ``StashScope``.
///
/// Conform the key type a package uses with `@Stash`, `@Stashed`, or
/// `SwiftStash.updates(forKey:in:bufferingPolicy:)`. Every wrapper declared with such a key
/// resolves its store from the scope, unless the declaration passes an explicit store.
///
/// ```swift
/// enum TipJarKey: String, StashScopedKey {
///     case tipCount
///     static var stashScope: StashScope { .tipJar }
/// }
/// ```
///
/// `@SecureStash` ignores the scope: the keychain is namespaced by `service`.
public protocol StashScopedKey: RawRepresentable where RawValue == String {
    /// The scope every key of this type belongs to.
    static var stashScope: StashScope { get }
}

package extension StashScope {
    /// The scope declared by the key's type, or `nil` for a key type without one.
    static func of<Key: RawRepresentable<String>>(_ key: Key) -> StashScope? {
        (Key.self as? any StashScopedKey.Type)?.stashScope
    }
}
