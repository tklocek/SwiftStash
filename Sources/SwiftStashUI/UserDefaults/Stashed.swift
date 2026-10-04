//
//  Stashed.swift
//  SwiftStash
//
// Copyright (c) 2026 SwiftStash contributors
// SPDX-License-Identifier: MIT
//

import Foundation
import SwiftStash
import SwiftUI
import Combine

/// A main-actor-isolated SwiftUI property wrapper backed by UserDefaults.
///
/// `Stashed` stores primitives, raw-representable enums, and Codable values using the same
/// representation as `Stash`. Its projected value is a `Binding`, and per-key KVO invalidates
/// the view for writes made through any UserDefaults API.
///
/// ```swift
/// @Stashed(key: "displayName", defaultValue: "")
/// var displayName: String
///
/// TextField("Display name", text: $displayName)
/// ```
///
/// ## Choosing the store
///
/// Like `@AppStorage` with `.defaultAppStorage(_:)`, a hosted `Stashed` takes its store from
/// the SwiftUI environment, so a test or preview can move a whole view hierarchy onto its own
/// suite with `.stashStore(_:)`. The store resolves in this order:
///
/// 1. an explicit `store:` argument;
/// 2. the environment: `.stashStore(_:for:)` for the key's scope, then
///    `.stashStore(_:)`;
/// 3. the store configured for the key's scope (`SwiftStash.configureUserDefaults(_:for:)`);
/// 4. the application-level store (`SwiftStash.configureUserDefaults(_:)`), else `.standard`.
///
/// Steps 3 and 4 are read when the wrapper is created. A wrapper used outside a view
/// hierarchy has no environment and uses that fallback.
///
/// Instances share an observer for the same UserDefaults object, key, and value type. Wrappers
/// that share a key must therefore use the same default value. Keys containing dots can be stored
/// but not observed because KVO interprets them as key paths.
///
/// Use `Stash` for non-view code and shared state that crosses concurrency domains.
@propertyWrapper @MainActor
public struct Stashed<Value: Sendable>: DynamicProperty {
    @Environment(\.stashStores) private var environmentStores
    /// Keeps the observer of a hosted wrapper alive across view re-initialisation and
    /// invalidates the view when it changes.
    @StateObject private var hostedObserver = StashedObserverBox<Value>()
    private let resolution: StashedResolution<Value>

    /// The current persisted value, or the wrapper's fallback when the key is absent or invalid.
    public var wrappedValue: Value {
        get {
            resolution.observer.currentValue
        }
        nonmutating set {
            resolution.observer.write(newValue)
        }
    }
    
    /// A two-way SwiftUI binding to the persisted value.
    public var projectedValue: Binding<Value> {
        Binding(
            get: { self.resolution.observer.currentValue },
            set: { self.resolution.observer.write($0) }
        )
    }

    /// Resolves the store from the environment before SwiftUI renders the view's body.
    public nonisolated func update() {
        MainActor.assumeIsolated {
            resolution.resolve(in: environmentStores, keepingAliveIn: hostedObserver)
        }
    }

    private init(
        key: String,
        store: UserDefaults?,
        scope: StashScope?,
        makeStorage: @escaping (UserDefaults) -> AnyUserDefaultsStorage<Value>
    ) {
        self.resolution = StashedResolution(
            key: key,
            explicitStore: store,
            scope: scope,
            makeStorage: makeStorage
        )
    }
    
    // MARK: - Primitive
    
    /// Creates a SwiftUI-aware wrapper for a property-list primitive.
    /// - Parameters:
    ///   - key: The UserDefaults key.
    ///   - defaultValue: The fallback returned when the key has no valid value.
    ///   - store: An explicit UserDefaults instance, or the environment's or globally configured
    ///     store when nil.
    public init(
        key: String,
        defaultValue: Value,
        store: UserDefaults? = nil
    ) where Value: UserDefaultsPrimitiveType {
        self.init(key: key, defaultValue: defaultValue, store: store, scope: nil)
    }

    init(
        key: String,
        defaultValue: Value,
        store: UserDefaults?,
        scope: StashScope?
    ) where Value: UserDefaultsPrimitiveType {
        self.init(key: key, store: store, scope: scope) { userDefaults in
            AnyUserDefaultsStorage(
                PrimitiveUserDefaultsStorage(
                    key: key,
                    defaultValue: defaultValue,
                    userDefaults: userDefaults
                )
            )
        }
    }

    /// Creates a SwiftUI-aware property wrapper for primitive values in UserDefaults
    /// using `@AppStorage`-style syntax.
    /// - Parameters:
    ///   - wrappedValue: The default value to return if no value is stored.
    ///   - key: The key to store the value under in UserDefaults.
    ///   - store: The UserDefaults instance to use. Defaults to the environment's or globally
    ///     configured instance.
    public init(
        wrappedValue: Value,
        _ key: String,
        store: UserDefaults? = nil
    ) where Value: UserDefaultsPrimitiveType {
        self.init(key: key, defaultValue: wrappedValue, store: store)
    }
}

// MARK: - Optional primitives

public extension Stashed where Value: ExpressibleByNilLiteral & UserDefaultsPrimitiveType {
    init(
        key: String,
        store: UserDefaults? = nil
    ) {
        self.init(key: key, defaultValue: nil, store: store)
    }

    /// Creates a SwiftUI-aware property wrapper for optional primitive values in UserDefaults
    /// using `@AppStorage`-style syntax.
    /// - Parameters:
    ///   - key: The key to store the value under in UserDefaults.
    ///   - store: The UserDefaults instance to use. Defaults to the environment's or globally
    ///     configured instance.
    init(
        _ key: String,
        store: UserDefaults? = nil
    ) {
        self.init(key: key, store: store)
    }
}

extension Stashed where Value: ExpressibleByNilLiteral & UserDefaultsPrimitiveType {
    init(
        key: String,
        store: UserDefaults?,
        scope: StashScope?
    ) {
        self.init(key: key, defaultValue: nil, store: store, scope: scope)
    }
}

// MARK: - Codable

public extension Stashed where Value: Codable {
    init(
        codable key: String,
        defaultValue: Value,
        store: UserDefaults? = nil,
        encoder: JSONEncoder? = nil,
        decoder: JSONDecoder? = nil
    ) {
        self.init(
            codable: key,
            defaultValue: defaultValue,
            store: store,
            scope: nil,
            encoder: encoder,
            decoder: decoder
        )
    }

    /// Creates a SwiftUI-aware property wrapper for Codable values in UserDefaults
    /// using `@AppStorage`-style syntax.
    /// - Parameters:
    ///   - wrappedValue: The default value to return if no value is stored or decoding fails.
    ///   - key: The key to store the value under in UserDefaults.
    ///   - store: The UserDefaults instance to use. Defaults to the environment's or globally
    ///     configured instance.
    ///   - encoder: Custom JSON encoder (defaults to a standard `JSONEncoder`). Configure it
    ///     fully before passing it in; the wrapper keeps using this instance, so it must not
    ///     be mutated afterwards.
    ///   - decoder: Custom JSON decoder (defaults to a standard `JSONDecoder`). The same rule
    ///     applies: configure before passing, never mutate afterwards.
    init(
        wrappedValue: Value,
        codable key: String,
        store: UserDefaults? = nil,
        encoder: JSONEncoder? = nil,
        decoder: JSONDecoder? = nil
    ) {
        self.init(codable: key, defaultValue: wrappedValue, store: store, encoder: encoder, decoder: decoder)
    }
}

extension Stashed where Value: Codable {
    init(
        codable key: String,
        defaultValue: Value,
        store: UserDefaults?,
        scope: StashScope?,
        encoder: JSONEncoder?,
        decoder: JSONDecoder?
    ) {
        let encoder = encoder ?? JSONEncoder()
        let decoder = decoder ?? JSONDecoder()
        self.init(key: key, store: store, scope: scope) { userDefaults in
            AnyUserDefaultsStorage(
                CodableUserDefaultsStorage(
                    key: key,
                    defaultValue: defaultValue,
                    userDefaults: userDefaults,
                    encoder: encoder,
                    decoder: decoder
                )
            )
        }
    }
}

// MARK: - Optional codables

public extension Stashed where Value: Codable & ExpressibleByNilLiteral {
    init(
        codable key: String,
        store: UserDefaults? = nil,
        encoder: JSONEncoder? = nil,
        decoder: JSONDecoder? = nil
    ) {
        self.init(codable: key, defaultValue: nil, store: store, encoder: encoder, decoder: decoder)
    }
}

extension Stashed where Value: Codable & ExpressibleByNilLiteral {
    init(
        codable key: String,
        store: UserDefaults?,
        scope: StashScope?,
        encoder: JSONEncoder?,
        decoder: JSONDecoder?
    ) {
        self.init(
            codable: key,
            defaultValue: nil,
            store: store,
            scope: scope,
            encoder: encoder,
            decoder: decoder
        )
    }
}

// MARK: - RawRepresentable (Enums)

public extension Stashed where Value: RawRepresentable, Value.RawValue: PropertyListNativeType {
    /// Creates a property wrapper for storing RawRepresentable types (like enums) in UserDefaults.
    /// The raw value is stored directly, making it compatible with UserDefaults property list types.
    /// - Parameters:
    ///   - key: The key to store the value under in UserDefaults.
    ///   - defaultValue: The default value to return if no value is stored or conversion fails.
    ///   - store: The UserDefaults instance to use. Defaults to the environment's or globally
    ///     configured instance.
    init(
        key: String,
        defaultValue: Value,
        store: UserDefaults? = nil
    ) {
        self.init(key: key, defaultValue: defaultValue, store: store, scope: nil)
    }

    /// Creates a SwiftUI-aware property wrapper for RawRepresentable values in UserDefaults
    /// using `@AppStorage`-style syntax.
    /// - Parameters:
    ///   - wrappedValue: The default value to return if no value is stored or conversion fails.
    ///   - key: The key to store the value under in UserDefaults.
    ///   - store: The UserDefaults instance to use. Defaults to the environment's or globally
    ///     configured instance.
    init(
        wrappedValue: Value,
        _ key: String,
        store: UserDefaults? = nil
    ) {
        self.init(key: key, defaultValue: wrappedValue, store: store)
    }
}

extension Stashed where Value: RawRepresentable, Value.RawValue: PropertyListNativeType {
    init(
        key: String,
        defaultValue: Value,
        store: UserDefaults?,
        scope: StashScope?
    ) {
        self.init(key: key, store: store, scope: scope) { userDefaults in
            AnyUserDefaultsStorage(
                RawRepresentableUserDefaultsStorage(
                    key: key,
                    defaultValue: defaultValue,
                    userDefaults: userDefaults
                )
            )
        }
    }
}

// MARK: - Optional RawRepresentable

public extension Stashed {
    /// Creates a property wrapper for storing optional RawRepresentable types in UserDefaults.
    /// - Parameters:
    ///   - key: The key to store the value under in UserDefaults.
    ///   - store: The UserDefaults instance to use. Defaults to the environment's or globally
    ///     configured instance.
    init<Wrapped>(
        key: String,
        store: UserDefaults? = nil
    ) where Value == Wrapped?, Wrapped: RawRepresentable, Wrapped.RawValue: PropertyListNativeType {
        self.init(key: key, store: store, scope: nil)
    }

    /// Creates a property wrapper for storing optional RawRepresentable values in UserDefaults
    /// using `@AppStorage`-style syntax.
    /// - Parameters:
    ///   - key: The key to store the value under in UserDefaults.
    ///   - store: The UserDefaults instance to use. Defaults to the environment's or globally
    ///     configured instance.
    init<Wrapped>(
        _ key: String,
        store: UserDefaults? = nil
    ) where Value == Wrapped?, Wrapped: RawRepresentable, Wrapped.RawValue: PropertyListNativeType {
        self.init(key: key, store: store)
    }
}

extension Stashed {
    init<Wrapped>(
        key: String,
        store: UserDefaults?,
        scope: StashScope?
    ) where Value == Wrapped?, Wrapped: RawRepresentable, Wrapped.RawValue: PropertyListNativeType {
        self.init(key: key, store: store, scope: scope) { userDefaults in
            AnyUserDefaultsStorage(
                OptionalRawRepresentableUserDefaultsStorage<Wrapped>(
                    key: key,
                    userDefaults: userDefaults
                )
            )
        }
    }
}

// MARK: - Store Resolution

/// Resolves which store one `Stashed` instance reads and writes.
///
/// Created with each `Stashed` initialisation. Outside a view hierarchy the observer is
/// resolved lazily from the fallback store; when hosted, `Stashed.update()` resolves the
/// environment first, so a view under `.stashStore(_:)` never creates an observer on the
/// fallback store.
@MainActor
private final class StashedResolution<Value: Sendable> {
    private let key: String
    private let explicitStore: UserDefaults?
    private let scope: StashScope?
    /// The explicit store, else the configured one, captured at initialisation.
    private let fallbackStore: UserDefaults
    private let makeStorage: (UserDefaults) -> AnyUserDefaultsStorage<Value>
    private var resolvedObserver: StashedObserver<Value>?

    init(
        key: String,
        explicitStore: UserDefaults?,
        scope: StashScope?,
        makeStorage: @escaping (UserDefaults) -> AnyUserDefaultsStorage<Value>
    ) {
        self.key = key
        self.explicitStore = explicitStore
        self.scope = scope
        self.fallbackStore = explicitStore ?? StashConfiguration.shared.resolveUserDefaults(for: scope)
        self.makeStorage = makeStorage
    }

    var observer: StashedObserver<Value> {
        if let resolvedObserver {
            return resolvedObserver
        }
        let observer = StashedObserverCache.observer(store: fallbackStore, key: key, makeStorage: makeStorage)
        resolvedObserver = observer
        return observer
    }

    func resolve(in environment: StashStoreEnvironment, keepingAliveIn box: StashedObserverBox<Value>) {
        let store = explicitStore ?? environment.store(for: scope) ?? fallbackStore
        let observer = StashedObserverCache.observer(store: store, key: key, makeStorage: makeStorage)
        box.track(observer)
        resolvedObserver = observer
    }
}

/// Holds the observer of a hosted `Stashed` and forwards its changes to SwiftUI.
///
/// Lives in a `@StateObject`, so it survives the view's re-initialisation; switching to
/// another observer (the environment's store changed) releases the old one, which tears
/// down its KVO registration once nothing else shares it.
@MainActor
private final class StashedObserverBox<Value: Sendable>: ObservableObject {
    private var observer: StashedObserver<Value>?
    private var forwarding: AnyCancellable?

    func track(_ observer: StashedObserver<Value>) {
        guard observer !== self.observer else { return }
        self.observer = observer
        // No send on the switch itself: this runs during the view update that is about to
        // render the new store's value anyway.
        forwarding = observer.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
    }
}

// MARK: - Observer Cache

/// Hands out one `StashedObserver` per (store, key, value type).
///
/// SwiftUI re-runs a view's initialiser on every parent re-render, which re-creates the
/// `Stashed` struct. Without sharing, each re-render would allocate a fresh observer,
/// Combine pipeline, and KVO registration, and drop any in-flight debounced update.
/// Entries are weak: when the last `Stashed` referencing an observer goes away, the
/// observer deallocates, its subscriptions cancel, and `StashNotificationCenter`
/// releases the underlying KVO observation.
@MainActor
private enum StashedObserverCache {
    private struct Key: Hashable {
        let store: ObjectIdentifier
        let key: String
        let valueType: ObjectIdentifier
    }

    private final class WeakBox {
        weak var object: AnyObject?
        init(_ object: AnyObject) { self.object = object }
    }

    private static var boxes: [Key: WeakBox] = [:]

    static func observer<Value: Sendable>(
        store: UserDefaults,
        key: String,
        makeStorage: (UserDefaults) -> AnyUserDefaultsStorage<Value>
    ) -> StashedObserver<Value> {
        let cacheKey = Key(
            store: ObjectIdentifier(store),
            key: key,
            valueType: ObjectIdentifier(Value.self)
        )

        if let existing = boxes[cacheKey]?.object as? StashedObserver<Value> {
            return existing
        }

        boxes = boxes.filter { $0.value.object != nil }

        let observer = StashedObserver(makeStorage(store))
        boxes[cacheKey] = WeakBox(observer)
        return observer
    }
}

// MARK: - Observer

/// ObservableObject that wraps UserDefaults storage with reactive updates.
/// Listens to notifications and publishes changes to SwiftUI views.
///
/// `currentValue` always mirrors what a fresh read of the store returns: a write goes through
/// ``write(_:)``, which reads the stored value back before publishing it. A write need not
/// round-trip — assigning `nil` to an optional with a non-nil default removes the key and reads
/// back the default; a failed `Codable` encode keeps the previously stored value — and the view
/// must never render the assigned value in between.
///
/// Instances are shared per (store, key, value type) via `StashedObserverCache`; the
/// `defaultValue` (and, for Codable storage, the encoder/decoder pair) captured in
/// `storage` therefore comes from the first live `Stashed` for that combination —
/// use the same default and coders for wrappers sharing a key.
@MainActor
fileprivate final class StashedObserver<Value: Sendable>: ObservableObject {
    private let storage: AnyUserDefaultsStorage<Value>
    private var cancellables = Set<AnyCancellable>()

    @Published private(set) var currentValue: Value

    init(_ storage: AnyUserDefaultsStorage<Value>) {
        self.storage = storage
        
        let initialValue = storage.get()
        _currentValue = Published(initialValue: initialValue)
        self.currentValue = initialValue
        
        // Listen for external changes to UserDefaults
        StashNotificationCenter.shared
            .publisher(for: storage.key, in: storage.store)
            .debounceForStash()
            .sink { [weak self] in
                guard let self else { return }
                let newValue = self.storage.get()
                if self.shouldUpdate(from: self.currentValue, to: newValue) {
                    let typeName = String(describing: Value.self)
                    Logging.logOperation("UPDATE", key: self.storage.key, type: typeName)
                    self.currentValue = newValue
                }
            }
            .store(in: &cancellables)
    }

    /// Writes `newValue` to the store, then publishes the value the store now holds.
    func write(_ newValue: Value) {
        if shouldUpdate(from: storage.get(), to: newValue) {
            storage.set(newValue)
            StashNotificationCenter.shared.notify(key: storage.key, in: storage.store)
        } else {
            let typeName = String(describing: Value.self)
            Logging.logOperation("SKIP SET (value unchanged)", key: storage.key, type: typeName)
        }

        let storedValue = storage.get()
        if shouldUpdate(from: currentValue, to: storedValue) {
            currentValue = storedValue
        }
    }
    
    private func shouldUpdate(from oldValue: Value, to newValue: Value) -> Bool {
        if let old = oldValue as? any Equatable,
           let new = newValue as? any Equatable {
            return !isEqual(old, new)
        }
        return true
    }
    
    private func isEqual(_ lhs: any Equatable, _ rhs: any Equatable) -> Bool {
        guard type(of: lhs) == type(of: rhs) else { return false }
        
        func compare<T: Equatable>(_ a: T, _ b: Any) -> Bool {
            guard let bTyped = b as? T else { return false }
            return a == bTyped
        }
        
        return compare(lhs, rhs)
    }
}
