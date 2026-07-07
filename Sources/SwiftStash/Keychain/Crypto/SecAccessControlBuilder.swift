//
//  SecAccessControlBuilder.swift
//  SwiftStash
//
// Copyright (c) 2026 SwiftStash contributors
// SPDX-License-Identifier: MIT
//

import Foundation
import Security

/// Internal helper centralising the only call to `SecAccessControlCreateWithFlags`
/// inside the package.
///
/// Maps the public ``KeychainAccessibility`` + ``SecAccessControlFlags`` pair
/// to the Security framework primitives and translates any failure to a
/// ``KeychainError``.
enum SecAccessControlBuilder {

    /// Builds a `SecAccessControl` object from the public Swift types.
    ///
    /// - Parameters:
    ///   - accessibility: The accessibility constant baked into the access
    ///     control object.
    ///   - flags: Additional user-presence / biometry / passcode constraints.
    /// - Returns: A configured `SecAccessControl`.
    /// - Throws: ``KeychainError/accessControlCreationFailed`` if
    ///   `SecAccessControlCreateWithFlags` returns `nil`.
    static func make(
        accessibility: KeychainAccessibility,
        flags: SecAccessControlFlags
    ) throws(KeychainError) -> SecAccessControl {
        var error: Unmanaged<CFError>?
        let access = unsafe SecAccessControlCreateWithFlags(
            kCFAllocatorDefault,
            accessibility.secValue,
            flags.secFlags,
            &error
        )
        guard let access else {
            unsafe error?.release()
            throw KeychainError.accessControlCreationFailed
        }
        return access
    }
}
