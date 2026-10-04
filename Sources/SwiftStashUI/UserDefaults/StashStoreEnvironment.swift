//
//  StashStoreEnvironment.swift
//  SwiftStash
//
// Copyright (c) 2026 SwiftStash contributors
// SPDX-License-Identifier: MIT
//

import Foundation
import SwiftStash
import SwiftUI

/// The stores a view hierarchy hands to its `@Stashed` wrappers.
///
/// SwiftUI does not expose `defaultAppStorage` for reading, so SwiftStash carries its own
/// environment value.
struct StashStoreEnvironment {
    /// The store for every wrapper without a more specific scoped store.
    var all: UserDefaults?
    /// Stores for wrappers whose key type declares one of these scopes.
    var scoped: [StashScope: UserDefaults] = [:]

    /// The environment's store for a wrapper in `scope`, or `nil` when the environment
    /// sets none and the wrapper falls back to its configured store.
    func store(for scope: StashScope?) -> UserDefaults? {
        if let scope, let scopedStore = scoped[scope] {
            return scopedStore
        }
        return all
    }
}

private struct StashStoreEnvironmentKey: EnvironmentKey {
    static var defaultValue: StashStoreEnvironment { StashStoreEnvironment() }
}

extension EnvironmentValues {
    var stashStores: StashStoreEnvironment {
        get { self[StashStoreEnvironmentKey.self] }
        set { self[StashStoreEnvironmentKey.self] = newValue }
    }
}

public extension View {
    /// Sets the UserDefaults store that `@Stashed` wrappers in this view hierarchy read and write.
    ///
    /// The `SwiftStash` counterpart of `.defaultAppStorage(_:)`, and typically applied
    /// alongside it. It covers every `@Stashed` below this view, including wrappers whose key
    /// type declares a `StashScope`, unless a nearer modifier sets a store for that
    /// scope. A wrapper declared with an explicit `store:` keeps it.
    ///
    /// ```swift
    /// SettingsView()
    ///     .defaultAppStorage(testDefaults)
    ///     .stashStore(testDefaults)
    /// ```
    ///
    /// The modifier nearest the view wins: applying it replaces any stores set further up,
    /// scoped ones included. It affects `@Stashed` only; `@Stash` has no environment and keeps
    /// the store it resolved at initialisation.
    /// - Parameter store: The store for every `@Stashed` in this view hierarchy.
    func stashStore(_ store: UserDefaults) -> some View {
        environment(\.stashStores, StashStoreEnvironment(all: store))
    }

    /// Sets the UserDefaults store for the `@Stashed` wrappers in this view hierarchy whose key
    /// type declares `scope`.
    ///
    /// Wrappers in other scopes, or in none, are unaffected. A wrapper declared with an
    /// explicit `store:` keeps it.
    ///
    /// ```swift
    /// TipJarView()
    ///     .stashStore(tipJarTestDefaults, for: .tipJar)
    /// ```
    /// - Parameters:
    ///   - store: The store for the scope's wrappers in this view hierarchy.
    ///   - scope: The scope to redirect.
    func stashStore(_ store: UserDefaults, for scope: StashScope) -> some View {
        transformEnvironment(\.stashStores) { stores in
            stores.scoped[scope] = store
        }
    }
}
