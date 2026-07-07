//
//  SecureStash.swift
//  SwiftStash
//
// Copyright (c) 2026 SwiftStash contributors
// SPDX-License-Identifier: MIT
//

import Foundation

/// A property wrapper for type-safe Keychain access with logging support.
///
/// SecureStash provides a simple, type-safe way to store sensitive values in the system Keychain
/// with built-in logging capabilities for debugging and monitoring.
///
/// ## Quick Start
///
/// ```swift
/// // 1. Configure the required service, typically in App.init()
/// SwiftStash.configureKeychain(
///     service: Bundle.main.bundleIdentifier!,
///     accessibility: .whenUnlockedThisDeviceOnly
/// )
/// SwiftStash.configureLogging(level: .normal)
///
/// // 2. Use @SecureStash property wrapper
/// @SecureStash(key: "authToken")
/// var authToken: String?
///
/// // 3. Use it like any normal property
/// authToken = "secret_token_12345"
/// print(authToken)  // Optional("secret_token_12345")
/// authToken = nil   // Deletes from keychain
/// ```
///
/// ## Configuration Flexibility
///
/// SecureStash supports multiple configuration patterns:
///
/// ### Pattern 1: Fully Manual (no global configuration)
/// ```swift
/// @SecureStash(
///     key: "token",
///     service: "com.myapp",
///     accessibility: .whenUnlockedThisDeviceOnly
/// )
/// var token: String?
/// ```
///
/// ### Pattern 2: Global Defaults
/// ```swift
/// // Set once at app launch
/// SwiftStash.configureKeychain(
///     service: "com.myapp",
///     accessibility: .whenUnlockedThisDeviceOnly
/// )
///
/// // Use everywhere
/// @SecureStash(key: "token")
/// var token: String?
///
/// @SecureStash(codable: "userId")
/// var userId: Int?
/// ```
///
/// ### Pattern 3: Global Defaults with Overrides
/// ```swift
/// // Global defaults
/// SwiftStash.configureKeychain(
///     service: "com.myapp",
///     accessibility: .whenUnlockedThisDeviceOnly
/// )
///
/// // Most items use defaults
/// @SecureStash(key: "token")
/// var token: String?
///
/// // Override for sensitive data
/// @SecureStash(
///     key: "biometricKey",
///     accessibility: .whenPasscodeSetThisDeviceOnly
/// )
/// var biometricKey: Data?
/// ```
///
/// ## Usage Examples
///
/// ```swift
/// // String values
/// @SecureStash(key: "username")
/// var username: String?
///
/// @SecureStash(key: "apiKey")
/// var apiKey: String?
///
/// // Data values
/// @SecureStash(key: "encryptionKey")
/// var encryptionKey: Data?
///
/// // Codable types
/// struct Credentials: Codable {
///     let username: String
///     let password: String
/// }
///
/// @SecureStash(codable: "credentials")
/// var credentials: Credentials?
///
/// // Internet passwords with domain
/// @SecureStash(
///     key: "password",
///     itemClass: .internetPassword(domain: "api.example.com")
/// )
/// var apiPassword: String?
/// ```
///
/// ## Important Notes
///
/// - Setting a value to `nil` **deletes** it from the Keychain
/// - All values are optional (non-optional values not supported for security reasons)
/// - The projected value (`$property`) is a ``SecureStashHandle``: `exists`, `remove()`, `key`
/// - A service is required, either globally or in each wrapper initialiser
/// - String and Data use `key:`; other `Codable` values use `codable:`
/// - Keychain items persist across app launches; reinstall behaviour is controlled by the platform
/// - Use appropriate accessibility levels for your security requirements
@propertyWrapper
public struct SecureStash<Value: Sendable>: Sendable {
    private let storage: AnyKeychainStorage<Value>
    
    public var wrappedValue: Value {
        get { storage.get() }
        nonmutating set { storage.set(newValue) }
    }

    /// A ``SecureStashHandle`` for this property, accessed as `$property`.
    ///
    /// The handle answers questions the wrapped value alone cannot:
    /// `$property.exists` checks item presence without reading or decoding it,
    /// and `$property.remove()` deletes the item explicitly.
    public var projectedValue: SecureStashHandle<Value> {
        SecureStashHandle(storage: storage)
    }

    // MARK: - Data Storage
    
    /// Creates a property wrapper for storing Data values in the Keychain.
    /// - Parameters:
    ///   - key: The key to store the value under in the Keychain.
    ///   - service: Service identifier (defaults to value from ``SwiftStash/configureKeychain(service:accessibility:isSynchronizable:itemClass:)``).
    ///   - accessibility: Keychain accessibility level (defaults to global or `.whenPasscodeSetThisDeviceOnly`).
    ///   - isSynchronizable: Whether to sync via iCloud (defaults to global or `false`).
    ///   - itemClass: Keychain item class (defaults to global or `.genericPassword`).
    public init(
        key: String,
        service: String? = nil,
        accessibility: KeychainAccessibility? = nil,
        isSynchronizable: Bool? = nil,
        itemClass: KeychainItemClass? = nil
    ) where Value == Data? {
        let config = resolveSecureStashConfiguration(
            key: key,
            service: service,
            accessibility: accessibility,
            isSynchronizable: isSynchronizable,
            itemClass: itemClass
        )

        self.storage = AnyKeychainStorage(
            KeychainItemStorage(key: key, configuration: config, coder: DataKeychainCoder())
        )
    }
}

// MARK: - String Storage

public extension SecureStash where Value == String? {
    /// Creates a property wrapper for storing String values in the Keychain.
    /// Strings are automatically converted to/from UTF-8 Data.
    /// - Parameters:
    ///   - key: The key to store the value under in the Keychain.
    ///   - service: Service identifier (defaults to global configuration or requires manual setup).
    ///   - accessibility: Keychain accessibility level (defaults to global or `.whenPasscodeSetThisDeviceOnly`).
    ///   - isSynchronizable: Whether to sync via iCloud (defaults to global or `false`).
    ///   - itemClass: Keychain item class (defaults to global or `.genericPassword`).
    init(
        key: String,
        service: String? = nil,
        accessibility: KeychainAccessibility? = nil,
        isSynchronizable: Bool? = nil,
        itemClass: KeychainItemClass? = nil
    ) {
        let config = resolveSecureStashConfiguration(
            key: key,
            service: service,
            accessibility: accessibility,
            isSynchronizable: isSynchronizable,
            itemClass: itemClass
        )

        self.storage = AnyKeychainStorage(
            KeychainItemStorage(key: key, configuration: config, coder: StringKeychainCoder())
        )
    }
}

// MARK: - Codable Storage

public extension SecureStash {
    /// Creates a property wrapper for storing Codable types in the Keychain using JSON encoding.
    /// - Parameters:
    ///   - key: The key to store the value under in the Keychain.
    ///   - service: Service identifier (defaults to global configuration or requires manual setup).
    ///   - accessibility: Keychain accessibility level (defaults to global or `.whenPasscodeSetThisDeviceOnly`).
    ///   - isSynchronizable: Whether to sync via iCloud (defaults to global or `false`).
    ///   - itemClass: Keychain item class (defaults to global or `.genericPassword`).
    ///   - encoder: Custom JSON encoder (defaults to a standard `JSONEncoder`). Configure it
    ///     fully before passing it in; the wrapper keeps using this instance, so it must not
    ///     be mutated afterwards.
    ///   - decoder: Custom JSON decoder (defaults to a standard `JSONDecoder`). The same rule
    ///     applies: configure before passing, never mutate afterwards.
    init<T: Codable>(
        codable key: String,
        service: String? = nil,
        accessibility: KeychainAccessibility? = nil,
        isSynchronizable: Bool? = nil,
        itemClass: KeychainItemClass? = nil,
        encoder: JSONEncoder? = nil,
        decoder: JSONDecoder? = nil
    ) where Value == T? {
        let config = resolveSecureStashConfiguration(
            key: key,
            service: service,
            accessibility: accessibility,
            isSynchronizable: isSynchronizable,
            itemClass: itemClass
        )

        self.storage = AnyKeychainStorage(
            KeychainItemStorage(
                key: key,
                configuration: config,
                coder: CodableKeychainCoder<T>(
                    encoder: encoder ?? JSONEncoder(),
                    decoder: decoder ?? JSONDecoder()
                )
            )
        )
    }
}

// MARK: - Configuration Resolution

/// Per-wrapper keychain settings after merging overrides with the global configuration.
private struct ResolvedSecureStashConfiguration {
    let service: String
    let accessibility: KeychainAccessibility
    let isSynchronizable: Bool
    let itemClass: KeychainItemClass
}

/// Merges per-wrapper overrides with ``SecureStashConfiguration``, traps when no service
/// is available, and runs the static misconfiguration checks. Shared by every initialiser.
private func resolveSecureStashConfiguration(
    key: String,
    service: String?,
    accessibility: KeychainAccessibility?,
    isSynchronizable: Bool?,
    itemClass: KeychainItemClass?
) -> ResolvedSecureStashConfiguration {
    let config = SecureStashConfiguration.shared

    guard let resolvedService = config.service(override: service) else {
        fatalError("SecureStash: service must be provided either via SwiftStash.configureKeychain(service:) or per-wrapper. Use SwiftStash.configureKeychain(service: \"...\") or provide service parameter.")
    }

    let resolved = ResolvedSecureStashConfiguration(
        service: resolvedService,
        accessibility: config.accessibility(override: accessibility),
        isSynchronizable: config.isSynchronizable(override: isSynchronizable),
        itemClass: config.itemClass(override: itemClass)
    )

    validateSecureStashConfiguration(
        key: key,
        accessibility: resolved.accessibility,
        isSynchronizable: resolved.isSynchronizable
    )

    return resolved
}

// MARK: - Configuration Validation

/// Flags the one statically-detectable misconfiguration: iCloud Keychain cannot sync
/// `*ThisDeviceOnly` items, so every write would fail at runtime with an opaque `errSecParam`.
/// Traps in debug builds; logs (and lets the runtime failure surface as before) in release.
private func validateSecureStashConfiguration(
    key: String,
    accessibility: KeychainAccessibility,
    isSynchronizable: Bool
) {
    guard isSynchronizable && accessibility.isThisDeviceOnly else { return }

    Logging.logError(
        "SecureStash: isSynchronizable is incompatible with \(accessibility) — iCloud Keychain cannot sync *ThisDeviceOnly items. Writes will fail.",
        key: key,
        storageType: .keychain
    )
    assertionFailure(
        "SecureStash(key: \"\(key)\"): isSynchronizable: true cannot be combined with .\(accessibility). Use a syncable accessibility such as .whenUnlocked or .afterFirstUnlock."
    )
}

// MARK: - Storage Protocol

private protocol KeychainStorage: Sendable {
    associatedtype StoredValue
    var key: String { get }
    func get() -> StoredValue
    func set(_ newValue: StoredValue)
    func exists() -> Bool
    func removeItem()
}

/// Type-erased keychain storage. `package` so ``SecureStashHandle`` can drive it;
/// constructed only in this file (the protocol behind it stays private).
package struct AnyKeychainStorage<Value>: Sendable {
    package let key: String
    private let _get: @Sendable () -> Value
    private let _set: @Sendable (Value) -> Void
    private let _exists: @Sendable () -> Bool
    private let _remove: @Sendable () -> Void

    fileprivate init<S: KeychainStorage>(_ storage: S) where S.StoredValue == Value {
        self.key = storage.key
        self._get = { storage.get() }
        self._set = { storage.set($0) }
        self._exists = { storage.exists() }
        self._remove = { storage.removeItem() }
    }

    package func get() -> Value {
        _get()
    }

    package func set(_ newValue: Value) {
        _set(newValue)
    }

    package func exists() -> Bool {
        _exists()
    }

    package func remove() {
        _remove()
    }
}

// MARK: - Storage Engine

/// Converts wrapper values to and from the `Data` stored in the keychain.
///
/// Coders log their own encode/decode outcomes; ``KeychainItemStorage`` logs the
/// keychain operations themselves.
private protocol KeychainValueCoder: Sendable {
    associatedtype Value
    /// Returns `nil` when the value cannot be encoded; the write is then skipped.
    func encode(_ value: Value, key: String) -> Data?
    /// Returns `nil` when the stored data cannot be decoded; the read then returns `nil`.
    func decode(_ data: Data, key: String) -> Value?
}

/// The single save/load/delete state machine behind every `@SecureStash` value type:
/// `nil` deletes the item, writes save and fall back to update on `.duplicateItem`,
/// and failures are logged instead of thrown. Value conversion is delegated to a coder.
private struct KeychainItemStorage<Coder: KeychainValueCoder>: KeychainStorage {
    typealias StoredValue = Coder.Value?

    let key: String
    private let service: String
    private let accessibility: KeychainAccessibility
    private let isSynchronizable: Bool
    private let itemClass: KeychainItemClass
    private let coder: Coder

    private var typeName: String { String(describing: Coder.Value.self) }

    init(key: String, configuration: ResolvedSecureStashConfiguration, coder: Coder) {
        self.key = key
        self.service = configuration.service
        self.accessibility = configuration.accessibility
        self.isSynchronizable = configuration.isSynchronizable
        self.itemClass = configuration.itemClass
        self.coder = coder
    }

    func get() -> Coder.Value? {
        do {
            guard let data = try KeychainRuntime.shared.backend.load(
                for: key,
                type: itemClass,
                service: service
            ) else {
                Logging.logOperation(
                    "GET (not found)",
                    key: key,
                    type: typeName,
                    itemClass: "\(itemClass)",
                    storageType: .keychain
                )
                return nil
            }

            guard let value = coder.decode(data, key: key) else { return nil }

            Logging.logOperation(
                "GET",
                key: key,
                type: typeName,
                itemClass: "\(itemClass)",
                storageType: .keychain
            )
            return value
        } catch let error where error == .itemNotFound {
            Logging.logOperation(
                "GET (not found)",
                key: key,
                type: typeName,
                itemClass: "\(itemClass)",
                storageType: .keychain
            )
            return nil
        } catch {
            Logging.logError(
                "GET failed: \(error.localizedDescription)",
                key: key,
                type: typeName,
                storageType: .keychain
            )
            return nil
        }
    }

    func set(_ newValue: Coder.Value?) {
        guard let value = newValue else {
            delete(operation: "DELETE (nil value)")
            return
        }

        guard let data = coder.encode(value, key: key) else { return }
        saveOrUpdate(data)
    }

    func exists() -> Bool {
        // Presence probe only — no decode, so a stored value the coder cannot
        // read still reports true. Matches items in any synchronizable state.
        do {
            return try KeychainRuntime.shared.backend.load(
                for: key,
                type: itemClass,
                service: service
            ) != nil
        } catch {
            return false
        }
    }

    func removeItem() {
        delete(operation: "DELETE (via handle)")
    }

    private func delete(operation: String) {
        do {
            try KeychainRuntime.shared.backend.delete(
                for: key,
                type: itemClass,
                service: service
            )
            Logging.logOperation(
                operation,
                key: key,
                type: typeName,
                itemClass: "\(itemClass)",
                storageType: .keychain
            )
        } catch let error where error == .itemNotFound {
            // Item doesn't exist, nothing to delete
            Logging.logOperation(
                "DELETE (already absent)",
                key: key,
                type: typeName,
                itemClass: "\(itemClass)",
                storageType: .keychain
            )
        } catch {
            Logging.logError(
                "DELETE failed: \(error.localizedDescription)",
                key: key,
                type: typeName,
                storageType: .keychain
            )
        }
    }

    private func saveOrUpdate(_ data: Data) {
        // Try to save (will fail if exists)
        do {
            try KeychainRuntime.shared.backend.save(
                data,
                for: key,
                type: itemClass,
                accessible: accessibility,
                synchronizable: isSynchronizable,
                service: service
            )
            Logging.logOperation(
                "SAVE",
                key: key,
                type: typeName,
                itemClass: "\(itemClass)",
                storageType: .keychain
            )
        } catch let error where error == .duplicateItem {
            // Item exists, update instead
            do {
                try KeychainRuntime.shared.backend.update(
                    data,
                    for: key,
                    type: itemClass,
                    accessible: accessibility,
                    service: service
                )
                Logging.logOperation(
                    "UPDATE",
                    key: key,
                    type: typeName,
                    itemClass: "\(itemClass)",
                    storageType: .keychain
                )
            } catch {
                Logging.logError(
                    "UPDATE failed: \(error.localizedDescription)",
                    key: key,
                    type: typeName,
                    storageType: .keychain
                )
            }
        } catch {
            Logging.logError(
                "SAVE failed: \(error.localizedDescription)",
                key: key,
                type: typeName,
                storageType: .keychain
            )
        }
    }
}

// MARK: - Coders

/// Stores `Data` values as-is.
private struct DataKeychainCoder: KeychainValueCoder {
    func encode(_ value: Data, key: String) -> Data? { value }
    func decode(_ data: Data, key: String) -> Data? { data }
}

/// Stores `String` values as UTF-8 `Data`.
private struct StringKeychainCoder: KeychainValueCoder {
    func encode(_ value: String, key: String) -> Data? {
        guard let data = value.data(using: .utf8) else {
            Logging.logError(
                "SET failed: Unable to encode string to UTF-8",
                key: key,
                type: "String",
                storageType: .keychain
            )
            return nil
        }
        Logging.logCoding("Successfully encoded", key: key, type: "String", storageType: .keychain)
        return data
    }

    func decode(_ data: Data, key: String) -> String? {
        guard let string = String(data: data, encoding: .utf8) else {
            Logging.logError(
                "GET failed: Unable to decode UTF-8 string",
                key: key,
                type: "String",
                storageType: .keychain
            )
            return nil
        }
        Logging.logCoding("Successfully decoded", key: key, type: "String", storageType: .keychain)
        return string
    }
}

/// Stores any `Codable` value as JSON-encoded `Data`.
///
/// Plain `Sendable`: the SDK annotates `JSONEncoder`/`JSONDecoder` as `Sendable`
/// (encode/decode build per-call state and only read the configuration), so the
/// structural conformance suffices. The configuration must not be mutated after
/// the coder is created — see the `encoder:`/`decoder:` parameter docs.
private struct CodableKeychainCoder<Value: Codable>: KeychainValueCoder {
    let encoder: JSONEncoder
    let decoder: JSONDecoder

    private var typeName: String { String(describing: Value.self) }

    func encode(_ value: Value, key: String) -> Data? {
        do {
            let data = try encoder.encode(value)
            Logging.logCoding("Successfully encoded", key: key, type: typeName, storageType: .keychain)
            return data
        } catch {
            Logging.logError(
                "Encoding failed: \(error.localizedDescription)",
                key: key,
                type: typeName,
                storageType: .keychain
            )
            return nil
        }
    }

    func decode(_ data: Data, key: String) -> Value? {
        do {
            let decoded = try decoder.decode(Value.self, from: data)
            Logging.logCoding("Successfully decoded", key: key, type: typeName, storageType: .keychain)
            return decoded
        } catch {
            Logging.logError(
                "GET/Decode failed: \(error.localizedDescription)",
                key: key,
                type: typeName,
                storageType: .keychain
            )
            return nil
        }
    }
}
