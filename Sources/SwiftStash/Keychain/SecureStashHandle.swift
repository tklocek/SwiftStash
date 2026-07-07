//
//  SecureStashHandle.swift
//  SwiftStash
//
// Copyright (c) 2026 SwiftStash contributors
// SPDX-License-Identifier: MIT
//

import Foundation

/// A handle to a `@SecureStash` property, exposed through its projected value (`$property`).
///
/// The handle answers questions the wrapped value alone cannot:
///
/// ```swift
/// @SecureStash(key: "authToken")
/// var authToken: String?
///
/// $authToken.exists      // item presence, without reading or decoding the value
/// $authToken.remove()    // deletes the item; same effect as authToken = nil
/// $authToken.key         // "authToken"
/// ```
///
/// `exists` is a pure presence probe: it reports `true` even when the stored data can
/// no longer be decoded into the wrapped type (in which case reads return `nil`). This
/// distinguishes "no item" from "item with unreadable payload".
///
/// Unlike ``StashHandle``, there is no `updates` stream — the keychain has no
/// change-notification mechanism to observe.
public struct SecureStashHandle<Value: Sendable>: Sendable {
    private let storage: AnyKeychainStorage<Value>

    package init(storage: AnyKeychainStorage<Value>) {
        self.storage = storage
    }

    /// The keychain key (account) this stash reads and writes.
    public var key: String {
        storage.key
    }

    /// Whether an item is currently stored under the key.
    ///
    /// Matches the item regardless of its synchronizable state, and does not decode
    /// the payload — an undecodable item still reports `true` even though reading the
    /// wrapped value returns `nil`.
    public var exists: Bool {
        storage.exists()
    }

    /// Deletes the item from the keychain.
    ///
    /// Equivalent to assigning `nil` to the wrapped value; deleting an absent item is
    /// not an error. Failures are logged, mirroring wrapper write semantics.
    public func remove() {
        storage.remove()
    }
}
