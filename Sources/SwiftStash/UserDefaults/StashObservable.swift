//
//  StashObservable.swift
//  SwiftStash
//
// Copyright (c) 2026 SwiftStash contributors
// SPDX-License-Identifier: MIT
//

import Foundation
import Observation

/// An `@Observable` class whose `@Stash` properties take part in observation.
///
/// The `@Observable` macro rejects property wrappers on the properties it tracks, so a model
/// would otherwise keep a hidden stash, an observable mirror, and a method that copies one into
/// the other at launch. Conform the class instead and mark each stash `@ObservationIgnored`:
/// the wrapper reports reads and writes to the class's observation registrar itself.
///
/// ```swift
/// @MainActor @Observable
/// final class TimerViewModel: StashObservable {
///     @ObservationIgnored @Stash(.timerMinutes) var minutes: Int
///     var isRunning = false
/// }
/// ```
///
/// The value is read from the store on every access — there is no mirror to restore or forget.
/// Writes made elsewhere — a `@Stashed` in a settings view, another wrapper on the same key, or
/// another process — reach the class's observers too, through key-value observation of the
/// key; those notifications arrive on the thread that wrote.
///
/// The `@Observable` macro supplies both requirements, so conforming takes no code. It generates
/// them `internal`, which is why a `public` class cannot conform. Combine with
/// ``StashContainer`` to also hold the store in the class.
@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
public protocol StashObservable: Observable, AnyObject {
    /// Registers a read of the property at `keyPath` with the observation registrar.
    func access<Member>(keyPath: KeyPath<Self, Member>)

    /// Performs `mutation` as a change of the property at `keyPath`, notifying observers.
    func withMutation<Member, MutationResult>(
        keyPath: KeyPath<Self, Member>,
        _ mutation: () throws -> MutationResult
    ) rethrows -> MutationResult
}

/// Connects one wrapper of a ``StashObservable`` class to its observation registrar.
///
/// Created with every `Stash`, used only when the enclosing instance is observable. On first
/// access it starts key-value observation of the wrapper's key, so writes that bypass the class
/// still notify its observers; it switches when a container's store changes.
///
/// `@unchecked` because the observer, its store identity, and the own-write depth are guarded
/// by `lock`.
final class StashObservationBridge<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var keyObserver: UserDefaultsKeyObserver?
    private var observedStore: ObjectIdentifier?
    /// Writes through the class already notify inside `withMutation`; the key-value
    /// notification they trigger on the same thread is skipped instead of reported twice.
    private var ownWriteDepth = 0

    @available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
    func read<Object: StashObservable>(
        _ storage: AnyUserDefaultsStorage<Value>,
        of object: Object,
        at keyPath: AnyKeyPath
    ) -> Value {
        guard let keyPath = keyPath as? KeyPath<Object, Value> else {
            return storage.get()
        }
        observeExternalWrites(to: storage, of: object, at: keyPath)
        object.access(keyPath: keyPath)
        return storage.get()
    }

    @available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
    func write<Object: StashObservable>(
        _ newValue: Value,
        to storage: AnyUserDefaultsStorage<Value>,
        of object: Object,
        at keyPath: AnyKeyPath
    ) {
        guard let keyPath = keyPath as? KeyPath<Object, Value> else {
            storage.set(newValue)
            return
        }
        observeExternalWrites(to: storage, of: object, at: keyPath)
        object.withMutation(keyPath: keyPath) {
            withLock { ownWriteDepth += 1 }
            defer { withLock { ownWriteDepth -= 1 } }
            storage.set(newValue)
        }
    }

    @available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
    private func observeExternalWrites<Object: StashObservable>(
        to storage: AnyUserDefaultsStorage<Value>,
        of object: Object,
        at keyPath: KeyPath<Object, Value>
    ) {
        withLock {
            let store = ObjectIdentifier(storage.store)
            guard observedStore != store else { return }
            let target: any ObservationTarget = KeyPathObservationTarget(object, keyPath)
            keyObserver = UserDefaultsKeyObserver(store: storage.store, key: storage.key) { [weak self] in
                guard let self, !self.withLock({ self.ownWriteDepth > 0 }) else { return }
                target.reportChange()
            }
            observedStore = store
        }
    }

    private func withLock<T>(_ body: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return body()
    }
}

/// Reports a change of one property of one observable instance. Non-generic, so the key-value
/// handler that holds it captures no generic type.
private protocol ObservationTarget: Sendable {
    func reportChange()
}

/// `@unchecked` because both stored properties are immutable after init (`weak` loads are
/// atomic), and the macro-generated `withMutation` is nonisolated and thread-safe.
@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
private final class KeyPathObservationTarget<Object: StashObservable, Value>: ObservationTarget, @unchecked Sendable {
    private weak var object: Object?
    private let keyPath: KeyPath<Object, Value>

    init(_ object: Object, _ keyPath: KeyPath<Object, Value>) {
        self.object = object
        self.keyPath = keyPath
    }

    func reportChange() {
        object?.withMutation(keyPath: keyPath) {}
    }
}
