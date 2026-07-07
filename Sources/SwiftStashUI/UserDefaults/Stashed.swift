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
/// Instances share an observer for the same UserDefaults object, key, and value type. Wrappers
/// that share a key must therefore use the same default value. Keys containing dots can be stored
/// but not observed because KVO interprets them as key paths.
///
/// Use `Stash` for non-view code and shared state that crosses concurrency domains.
@propertyWrapper @MainActor
public struct Stashed<Value: Sendable>: DynamicProperty {
    @ObservedObject private var observer: StashedObserver<Value>

    /// The current persisted value, or the wrapper's fallback when the key is absent or invalid.
    public var wrappedValue: Value {
        get {
            observer.currentValue
        }
        nonmutating set {
            observer.currentValue = newValue
        }
    }
    
    /// A two-way SwiftUI binding to the persisted value.
    public var projectedValue: Binding<Value> {
        Binding(
            get: { self.observer.currentValue },
            set: { self.observer.currentValue = $0 }
        )
    }
    
    // MARK: - Primitive
    
    /// Creates a SwiftUI-aware wrapper for a property-list primitive.
    /// - Parameters:
    ///   - key: The UserDefaults key.
    ///   - defaultValue: The fallback returned when the key has no valid value.
    ///   - store: An explicit UserDefaults instance, or the globally configured store when nil.
    public init(
        key: String,
        defaultValue: Value,
        store: UserDefaults? = nil
    ) where Value: UserDefaultsPrimitiveType {
        let resolvedStore = store ?? StashConfiguration.shared.userDefaults
        let storage = AnyUserDefaultsStorage(
            PrimitiveUserDefaultsStorage(
                key: key,
                defaultValue: defaultValue,
                userDefaults: resolvedStore
            )
        )
        self._observer = ObservedObject(wrappedValue: StashedObserverCache.observer(for: storage))
    }

    /// Creates a SwiftUI-aware property wrapper for primitive values in UserDefaults
    /// using `@AppStorage`-style syntax.
    /// - Parameters:
    ///   - wrappedValue: The default value to return if no value is stored.
    ///   - key: The key to store the value under in UserDefaults.
    ///   - store: The UserDefaults instance to use. Defaults to the globally configured instance.
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
    ///   - store: The UserDefaults instance to use. Defaults to the globally configured instance.
    init(
        _ key: String,
        store: UserDefaults? = nil
    ) {
        self.init(key: key, store: store)
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
        let resolvedStore = store ?? StashConfiguration.shared.userDefaults
        let storage = AnyUserDefaultsStorage(
            CodableUserDefaultsStorage(
                key: key,
                defaultValue: defaultValue,
                userDefaults: resolvedStore,
                encoder: encoder ?? JSONEncoder(),
                decoder: decoder ?? JSONDecoder()
            )
        )
        self._observer = ObservedObject(wrappedValue: StashedObserverCache.observer(for: storage))
    }

    /// Creates a SwiftUI-aware property wrapper for Codable values in UserDefaults
    /// using `@AppStorage`-style syntax.
    /// - Parameters:
    ///   - wrappedValue: The default value to return if no value is stored or decoding fails.
    ///   - key: The key to store the value under in UserDefaults.
    ///   - store: The UserDefaults instance to use. Defaults to the globally configured instance.
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

// MARK: - RawRepresentable (Enums)

public extension Stashed where Value: RawRepresentable, Value.RawValue: PropertyListNativeType {
    /// Creates a property wrapper for storing RawRepresentable types (like enums) in UserDefaults.
    /// The raw value is stored directly, making it compatible with UserDefaults property list types.
    /// - Parameters:
    ///   - key: The key to store the value under in UserDefaults.
    ///   - defaultValue: The default value to return if no value is stored or conversion fails.
    ///   - store: The UserDefaults instance to use. Defaults to the globally configured instance.
    init(
        key: String,
        defaultValue: Value,
        store: UserDefaults? = nil
    ) {
        let resolvedStore = store ?? StashConfiguration.shared.userDefaults
        let storage = AnyUserDefaultsStorage(
            RawRepresentableUserDefaultsStorage(
                key: key,
                defaultValue: defaultValue,
                userDefaults: resolvedStore
            )
        )
        self._observer = ObservedObject(wrappedValue: StashedObserverCache.observer(for: storage))
    }

    /// Creates a SwiftUI-aware property wrapper for RawRepresentable values in UserDefaults
    /// using `@AppStorage`-style syntax.
    /// - Parameters:
    ///   - wrappedValue: The default value to return if no value is stored or conversion fails.
    ///   - key: The key to store the value under in UserDefaults.
    ///   - store: The UserDefaults instance to use. Defaults to the globally configured instance.
    init(
        wrappedValue: Value,
        _ key: String,
        store: UserDefaults? = nil
    ) {
        self.init(key: key, defaultValue: wrappedValue, store: store)
    }
}

// MARK: - Optional RawRepresentable

public extension Stashed {
    /// Creates a property wrapper for storing optional RawRepresentable types in UserDefaults.
    /// - Parameters:
    ///   - key: The key to store the value under in UserDefaults.
    ///   - store: The UserDefaults instance to use. Defaults to the globally configured instance.
    init<Wrapped>(
        key: String,
        store: UserDefaults? = nil
    ) where Value == Wrapped?, Wrapped: RawRepresentable, Wrapped.RawValue: PropertyListNativeType {
        let resolvedStore = store ?? StashConfiguration.shared.userDefaults
        let storage = AnyUserDefaultsStorage(
            OptionalRawRepresentableUserDefaultsStorage<Wrapped>(
                key: key,
                userDefaults: resolvedStore
            )
        )
        self._observer = ObservedObject(wrappedValue: StashedObserverCache.observer(for: storage))
    }

    /// Creates a property wrapper for storing optional RawRepresentable values in UserDefaults
    /// using `@AppStorage`-style syntax.
    /// - Parameters:
    ///   - key: The key to store the value under in UserDefaults.
    ///   - store: The UserDefaults instance to use. Defaults to the globally configured instance.
    init<Wrapped>(
        _ key: String,
        store: UserDefaults? = nil
    ) where Value == Wrapped?, Wrapped: RawRepresentable, Wrapped.RawValue: PropertyListNativeType {
        self.init(key: key, store: store)
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
        for storage: AnyUserDefaultsStorage<Value>
    ) -> StashedObserver<Value> {
        let cacheKey = Key(
            store: ObjectIdentifier(storage.store),
            key: storage.key,
            valueType: ObjectIdentifier(Value.self)
        )

        if let existing = boxes[cacheKey]?.object as? StashedObserver<Value> {
            return existing
        }

        boxes = boxes.filter { $0.value.object != nil }

        let observer = StashedObserver(storage)
        boxes[cacheKey] = WeakBox(observer)
        return observer
    }
}

// MARK: - Observer

/// ObservableObject that wraps UserDefaults storage with reactive updates.
/// Listens to notifications and publishes changes to SwiftUI views.
///
/// Instances are shared per (store, key, value type) via `StashedObserverCache`; the
/// `defaultValue` (and, for Codable storage, the encoder/decoder pair) captured in
/// `storage` therefore comes from the first live `Stashed` for that combination —
/// use the same default and coders for wrappers sharing a key.
@MainActor
fileprivate final class StashedObserver<Value: Sendable>: ObservableObject {
    private let storage: AnyUserDefaultsStorage<Value>
    private var cancellables = Set<AnyCancellable>()

    @Published var currentValue: Value

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
        
        // Save changes to UserDefaults when currentValue changes
        $currentValue
            .dropFirst()
            .sink { [weak self] newValue in
                guard let self else { return }
                let storedValue = self.storage.get()
                if self.shouldUpdate(from: storedValue, to: newValue) {
                    self.storage.set(newValue)
                    StashNotificationCenter.shared.notify(key: self.storage.key, in: self.storage.store)
                } else {
                    let typeName = String(describing: Value.self)
                    Logging.logOperation("SKIP SET (value unchanged)", key: self.storage.key, type: typeName)
                }
            }
            .store(in: &cancellables)
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
