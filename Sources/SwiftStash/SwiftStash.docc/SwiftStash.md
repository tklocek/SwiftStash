# ``SwiftStash``

Type-safe property wrappers for UserDefaults and Keychain storage with integrated logging.

## Overview

The SwiftStash package provides two library products with a shared storage representation:

- `SwiftStash` is the Foundation-facing core for UserDefaults, Keychain, observation, and logging.
- `SwiftStashUI` adds the `@Stashed` SwiftUI `DynamicProperty` and its projected `Binding`.

Import only the product needed by each target. A SwiftUI view may import both products when it
uses `@Stashed` alongside core configuration or Keychain storage.

### Why not just @AppStorage?

`@AppStorage` requires SwiftUI and a `View` context, handles only property-list
primitives, offers no secure storage, and cannot be observed outside its own view.
SwiftStash removes all of these limits — `@Stash` works in any Foundation code
(view models, services, packages), stores any `Codable` type, pairs with
``SecureStash`` for Keychain secrets, and streams per-key changes via `AsyncStream` —
while using the **same storage representation** as `@AppStorage`, so adopting it
requires no data migration and can be done one property at a time. See
<doc:MigratingFromAppStorage> for the step-by-step playbook.

### Key Features

- **@Stash** - UserDefaults storage for preferences and app state
- **@SecureStash** - Keychain storage for sensitive data like tokens and passwords
- **Per-Key Observation** - `AsyncStream` updates for any key, from any writer
- **Unified Logging** - Configurable logging levels for both storage backends
- **Type-Safe** - Full support for primitives, enums, Codable types, and optionals
- **Thread-Safe Core Wrappers** - `Stash` and `SecureStash` are `Sendable` and safe as `static let` under Swift 6 strict concurrency
- **Zero Boilerplate** - Simple property wrapper syntax

> Tip: `@Stash`, `@Stashed`, and `@AppStorage` interoperate on overlapping value types and keys.

## Topics

### Getting Started

- <doc:GettingStarted>
- <doc:MigratingFromAppStorage>
- <doc:PackageProducts>
- <doc:UserDefaultsStorage>
- <doc:KeychainStorage>

### SwiftUI Product

- <doc:SwiftUIStorage>

### Advanced Features

- <doc:Logging>
- <doc:KeychainConfiguration>
- <doc:KeychainHelpers>
- <doc:KeychainCrypto>

### Property Wrappers

- ``Stash``
- ``SecureStash``
- ``StashHandle``
- ``SecureStashHandle``

### Type Safety

- ``UserDefaultsPrimitiveType``
- ``PropertyListNativeType``

### Configuration

- ``SwiftStash/logLevel``
- ``SwiftStash/configureLogging(level:)``
- ``SwiftStash/configureUserDefaults(suiteName:)``
- ``SwiftStash/configureKeychain(service:accessibility:isSynchronizable:itemClass:)``
- ``StashLogLevel``

### Keychain

- ``KeychainManager``
- ``KeychainAccessibility``
- ``KeychainItemClass``
- ``KeychainError``
- ``SecureStashHelpers``

### Biometrics & Secure Enclave

- ``KeychainCryptoManagerProtocol``
- ``CryptoKeyDescriptor``
- ``CryptoKeyAlgorithm``
- ``CryptoKeyStorage``
- ``SecAccessControlFlags``
