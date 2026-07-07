//
//  KeychainAccessibility.swift
//  SwiftStash
//
// Copyright (c) 2026 SwiftStash contributors
// SPDX-License-Identifier: MIT
//

import Foundation


/// A representation of the keychain accessibility levels, defining when a keychain item is accessible
/// and whether it is restricted to the current device.
///
/// These values correspond to `kSecAttrAccessible` constants in the Security framework,
/// and influence both **availability** and **backup/iCloud synchronisation behaviour**.
public enum KeychainAccessibility: Sendable {
    
    /// The data in the keychain item is accessible only while the device is unlocked.
    ///
    /// Items with this accessibility level can be migrated to a new device during backup/restore
    /// and may be synchronised to iCloud if `kSecAttrSynchronizable` is enabled.
    ///
    /// Corresponds to `kSecAttrAccessibleWhenUnlocked`.
    case whenUnlocked
    
    /// The data in the keychain item is accessible after the device has been unlocked once
    /// after a restart.
    ///
    /// Like `.whenUnlocked`, this allows migration and backup. Suitable for background tasks
    /// that may run without requiring the user to unlock the device again.
    ///
    /// Corresponds to `kSecAttrAccessibleAfterFirstUnlock`.
    case afterFirstUnlock
    
    /// The data in the keychain item is accessible only while the device is unlocked,
    /// and is restricted to the current device.
    ///
    /// This setting disables iCloud synchronisation and backup migration. It’s the most secure
    /// setting that still allows runtime access while the device is unlocked.
    ///
    /// Corresponds to `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`.
    case whenUnlockedThisDeviceOnly
    
    /// The data in the keychain item is accessible after the device has been unlocked once,
    /// and is restricted to the current device.
    ///
    /// Offers background task compatibility and migration protection.
    ///
    /// Corresponds to `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`.
    case afterFirstUnlockThisDeviceOnly
    
    /// The data in the keychain item is accessible only when the device is unlocked,
    /// and only if a passcode is set on the device.
    ///
    /// This is the most restrictive option and provides maximum protection.
    /// Items are not synchronised or backed up and will be deleted if the user removes the passcode.
    ///
    /// Corresponds to `kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly`.
    case whenPasscodeSetThisDeviceOnly
    
    /// Whether the level is restricted to the current device and therefore incompatible
    /// with iCloud Keychain synchronisation (`kSecAttrSynchronizable`).
    var isThisDeviceOnly: Bool {
        switch self {
            case .whenUnlocked, .afterFirstUnlock:
                return false
            case .whenUnlockedThisDeviceOnly, .afterFirstUnlockThisDeviceOnly, .whenPasscodeSetThisDeviceOnly:
                return true
        }
    }

    /// Returns the corresponding `CFString` constant used in the Security framework.
    var secValue: CFString {
        switch self {
            case .whenUnlocked: return kSecAttrAccessibleWhenUnlocked
            case .afterFirstUnlock: return kSecAttrAccessibleAfterFirstUnlock
            case .whenUnlockedThisDeviceOnly: return kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            case .afterFirstUnlockThisDeviceOnly: return kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            case .whenPasscodeSetThisDeviceOnly: return kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly
        }
    }
}
