//
//  SecureStashConfiguration.swift
//  SwiftStash
//
// Copyright (c) 2026 SwiftStash contributors
// SPDX-License-Identifier: MIT
//

import Foundation

/// Internal configuration for `@SecureStash` property wrappers.
///
/// Users should configure Keychain settings via ``SwiftStash/configureKeychain(service:accessibility:isSynchronizable:itemClass:)``.
///
/// Thread-safety is achieved using `NSLock`, which is appropriate here because:
/// 1. Property wrapper initialisers are synchronous (cannot use async/await or Mutex on iOS 14+)
/// 2. Configuration is typically write-once at launch, read-many thereafter (low contention)
final class SecureStashConfiguration: @unchecked Sendable {
    
    /// Shared instance for global configuration.
    static let shared = SecureStashConfiguration()
    
    private let lock = NSLock()
    
    // Global defaults (all optional)
    private var _service: String?
    private var _accessibility: KeychainAccessibility?
    private var _isSynchronizable: Bool?
    private var _itemClass: KeychainItemClass?
    
    private init() {}
    
    /// Configure global defaults for all @SecureStash wrappers.
    ///
    /// All parameters are optional. Only provide values for settings you want to apply globally.
    /// Individual wrappers can override these settings.
    ///
    /// - Parameters:
    ///   - service: Default service identifier (typically your app's bundle ID)
    ///   - accessibility: Default keychain accessibility level
    ///   - isSynchronizable: Default iCloud synchronisation setting
    ///   - itemClass: Default keychain item class (usually `.genericPassword`)
    func configure(
        service: String? = nil,
        accessibility: KeychainAccessibility? = nil,
        isSynchronizable: Bool? = nil,
        itemClass: KeychainItemClass? = nil
    ) {
        lock.lock()
        defer { lock.unlock() }
        
        if let service { _service = service }
        if let accessibility { _accessibility = accessibility }
        if let isSynchronizable { _isSynchronizable = isSynchronizable }
        if let itemClass { _itemClass = itemClass }
    }
    
    /// Reset all global configuration to defaults.
    func reset() {
        lock.lock()
        defer { lock.unlock() }
        
        _service = nil
        _accessibility = nil
        _isSynchronizable = nil
        _itemClass = nil
    }
    
    // MARK: - Getters with fallback to sensible defaults
    
    /// Get configured service or require it to be provided.
    /// - Parameter override: Optional override value
    /// - Returns: Service identifier or nil if not configured
    func service(override: String?) -> String? {
        lock.lock()
        defer { lock.unlock() }
        return override ?? _service
    }
    
    /// Get configured accessibility or use secure default.
    /// - Parameter override: Optional override value
    /// - Returns: Accessibility level (defaults to `.whenPasscodeSetThisDeviceOnly`)
    func accessibility(override: KeychainAccessibility?) -> KeychainAccessibility {
        lock.lock()
        defer { lock.unlock() }
        return override ?? _accessibility ?? .whenPasscodeSetThisDeviceOnly
    }
    
    /// Get configured synchronizability or use secure default.
    /// - Parameter override: Optional override value
    /// - Returns: Synchronizability flag (defaults to `false`)
    func isSynchronizable(override: Bool?) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return override ?? _isSynchronizable ?? false
    }
    
    /// Get configured item class or use default.
    /// - Parameter override: Optional override value
    /// - Returns: Item class (defaults to `.genericPassword`)
    func itemClass(override: KeychainItemClass?) -> KeychainItemClass {
        lock.lock()
        defer { lock.unlock() }
        return override ?? _itemClass ?? .genericPassword
    }
}
