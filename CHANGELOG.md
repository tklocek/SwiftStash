# Changelog

All notable changes to SwiftStash are documented in this file.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and the project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.2.0] - 2026-10-04

Stores you can choose and inject, keys that carry their default, and persisted properties in
`@Observable` models. No breaking changes to the public API and no persisted-data migration:
values written by 0.1.0 read as before.

### Added

- `StashKey<Value>`: a key that carries its value type and default, declared once
  (`extension StashKey<Int> { static var launchCount: Self { .init("launchCount", default: 0) } }`)
  and accepted by every `@Stash` and `@Stashed` variant (`@Stash(.launchCount) var launchCount: Int`,
  `codable:` for `Codable` values, optionals defaulting to `nil`) and by
  `SwiftStash.updates(forKey:)`, so a model and a view cannot disagree on a default.
- `StashContainer` and `StashStore`: a class states its UserDefaults store once
  (`let stashStore: StashStore`), and every `@Stash` property declared in it — and its
  projected value — reads and writes that store, so a test injects its suite without passing
  it to each property.
- `StashObservable` (iOS 17, macOS 14 and later): an `@Observable` class conforming to it
  marks its stashes `@ObservationIgnored @Stash(…)`, and their reads and writes take part in
  observation — no observable mirror, no restore at launch. Writes that bypass the class, such
  as a `@Stashed` in a settings view, notify its observers too.
- `.stashStore(_:)` and `.stashStore(_:for:)` view modifiers in `SwiftStashUI`: a hosted
  `@Stashed` takes its store from the SwiftUI environment, the counterpart of
  `.defaultAppStorage(_:)`, so tests and previews can keep a view hierarchy off the app's real
  preferences. When the environment's store changes, the wrapper switches to it.
- Package-level stores: `StashScope`, the `StashScopedKey` protocol (a key type declares its
  scope once), and `SwiftStash.configureUserDefaults(_:for:)`. A scope nobody configured falls
  back to the application-level store.
- `SwiftStash.configureUserDefaults(_:)`, which takes a `UserDefaults` instance; the
  `suiteName:` variant is now built on it.
- `SwiftStash.userDefaults`, `SwiftStash.userDefaults(for:)`, `SwiftStash.resetUserDefaults()`,
  and `SwiftStash.resetUserDefaults(for:)` to read and reset the configuration.

### Changed

- One documented resolution chain for `@Stash`, `@Stashed`, and
  `SwiftStash.updates(forKey:in:bufferingPolicy:)`: an explicit store, then the container's
  store (`@Stash` in a `StashContainer`) or the SwiftUI environment (hosted `@Stashed`), then
  the key's scope, then the application-level store, then `.standard`. Configured stores are
  still read once, when the wrapper is created; configuring after a wrapper has resolved its
  store is now logged as an error.
- Operation logs (`.normal` and above) are written at the unified log's `.debug` level
  instead of `.default`, which the system stores on disk: reads and writes no longer fill the
  persisted log and appear only while somebody streams it (the Xcode console, Console.app with
  debug messages, `log stream`). Errors stay at `.error`.

### Fixed

- `@Stashed` reads back the stored value right after a write instead of showing the assigned
  one until its debounced change notification arrives. Assigning `nil` to an optional with a
  non-nil default reads the default immediately (as `@Stash` does), a failed `Codable` encode
  keeps showing the previously stored value, and a view renders once per write.

## [0.1.0] - 2026-07-07

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

[Unreleased]: https://github.com/tklocek/SwiftStash/compare/v0.2.0...HEAD
[0.2.0]: https://github.com/tklocek/SwiftStash/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/tklocek/SwiftStash/releases/tag/v0.1.0
