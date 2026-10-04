//
//  StashContainer.swift
//  SwiftStash
//
// Copyright (c) 2026 SwiftStash contributors
// SPDX-License-Identifier: MIT
//

import Foundation

/// A class that holds the UserDefaults store for the `@Stash` properties declared in it.
///
/// Tests inject a per-test suite into a settings type, so every property needs the store. A
/// container states it once: each `@Stash` property of a conforming class reads and writes the
/// container's ``stashStore``, and so does its projected value (`$property.exists`, `.remove()`,
/// `.updates`).
///
/// ```swift
/// @MainActor
/// final class AppSettings: StashContainer {
///     let stashStore: StashStore
///
///     @Stash(.launchCount) var launchCount: Int
///     @Stash(.theme) var theme: Theme
///
///     init(defaults: UserDefaults = .standard) {
///         stashStore = StashStore(defaults)
///     }
/// }
///
/// let settings = AppSettings(defaults: testDefaults)   // every property on the test's suite
/// ```
///
/// The container's store takes the place of the configured stores: it wins over the key's
/// ``StashScope`` and the application level. A declaration that passes an explicit
/// `userDefaults:` keeps that store — the explicit store stays the one deliberate override.
///
/// Only classes can be containers: the wrapper reaches the store through its enclosing
/// instance, which Swift provides for class properties. A `@Stash` in a class that does not
/// conform behaves as before.
public protocol StashContainer: AnyObject {
    /// The store every `@Stash` property of this container reads and writes.
    var stashStore: StashStore { get }
}

/// The UserDefaults store of a ``StashContainer``.
///
/// A `Sendable` wrapper, so a main-actor class can satisfy ``StashContainer/stashStore`` with a
/// plain `let`: `UserDefaults` is thread-safe but not annotated `Sendable` in the SDK.
public struct StashStore: @unchecked Sendable {
    /// The wrapped store.
    public let userDefaults: UserDefaults

    /// Wraps a store for a ``StashContainer``.
    /// - Parameter userDefaults: The store the container's properties read and write.
    public init(_ userDefaults: UserDefaults) {
        self.userDefaults = userDefaults
    }
}

/// Builds and caches one wrapper's storage on its container's store.
///
/// A wrapper's storage is otherwise fixed at initialisation, before the container exists;
/// this rebinds it on first access and keeps it while the container's store stays the same.
///
/// `@unchecked` because the cached storage and store identity are guarded by `lock`, and the
/// factory is an immutable `@Sendable` closure.
final class StashContainerStorage<Value>: @unchecked Sendable {
    private let makeStorage: @Sendable (UserDefaults) -> AnyUserDefaultsStorage<Value>
    private let lock = NSLock()
    private var cached: (store: ObjectIdentifier, storage: AnyUserDefaultsStorage<Value>)?

    init(_ makeStorage: @escaping @Sendable (UserDefaults) -> AnyUserDefaultsStorage<Value>) {
        self.makeStorage = makeStorage
    }

    func storage(on store: UserDefaults) -> AnyUserDefaultsStorage<Value> {
        lock.lock()
        defer { lock.unlock() }
        let identifier = ObjectIdentifier(store)
        if let cached, cached.store == identifier {
            return cached.storage
        }
        let storage = makeStorage(store)
        cached = (identifier, storage)
        return storage
    }
}
