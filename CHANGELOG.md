# Changelog

All notable changes to SwiftStash are documented in this file.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and the project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0]

Initial public release of SwiftStash: type-safe persistence for UserDefaults,
Keychain, and SwiftUI with no third-party dependencies.

### Added

- `@Stash` for primitives, raw-representable values, `Codable` values, and
  optionals in UserDefaults. Compatible primitive and enum values use the same
  representation as `@AppStorage`, allowing incremental adoption without a data
  migration.
- `@SecureStash` for optional `String`, `Data`, and `Codable` values in the
  Keychain, with per-wrapper `service`, `accessibility`, `isSynchronizable`, and
  `itemClass` control.
- `@Stashed` in the `SwiftStashUI` product: a SwiftUI `DynamicProperty` with a
  projected `Binding` and updates for writes made through any compatible source.
- Projected values: `StashHandle` (`exists`, `remove()`, `key`, typed `updates`
  `AsyncStream`) and `SecureStashHandle` (`exists`, `remove()`, `key`).
- Per-key observation without a wrapper: `SwiftStash.updates(forKey:in:bufferingPolicy:)`.
- `KeychainManager` — a lower-level keychain CRUD API with typed
  `throws(KeychainError)`, plus biometric items and Secure Enclave or software
  key pairs. Crypto and biometric APIs are unavailable on tvOS.
- `SecureStashHelpers` — `exists`, `allKeys`, `clearAll` batch/introspection helpers.
- One-line global configuration: `SwiftStash.configureUserDefaults(suiteName:)`,
  `SwiftStash.configureKeychain(...)`, `SwiftStash.logLevel`.
- Privacy-preserving OSLog logging (keys `.private`, type names `.public`).
- Swift 6 language mode with strict memory safety; the core wrappers are
  `Sendable` and usable as `static let` under strict concurrency.
- Support for iOS 14+, macOS 11+, tvOS 14+, watchOS 9+, visionOS 1+, and Mac
  Catalyst 14+.
- Example iOS app, SPM snippets, and optional Xcode file templates.
