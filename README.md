<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="Branding/Assets/swiftstash-lockup-dark.svg">
    <img src="Branding/Assets/swiftstash-lockup-light.svg" alt="SwiftStash" width="420">
  </picture>
</p>

<p align="center"><b>Type-safe, property wrapper-based persistence for Swift</b><br>
UserDefaults · Keychain · SwiftUI — with built-in privacy-preserving logging.</p>

<p align="center">
  <a href="https://www.swift.org/"><img src="https://img.shields.io/badge/Swift-6.2-F05138?style=flat-square&logo=swift&logoColor=white" alt="Swift 6.2"></a>
  <a href="#requirements"><img src="https://img.shields.io/badge/Platforms-iOS%20%7C%20macOS%20%7C%20tvOS%20%7C%20watchOS%20%7C%20visionOS%20%7C%20Mac%20Catalyst-0A84FF?style=flat-square&logo=apple&logoColor=white" alt="Platforms"></a>
  <a href="#installation"><img src="https://img.shields.io/badge/SPM-compatible-F05138?style=flat-square&logo=swift&logoColor=white" alt="Swift Package Manager"></a>
  <a href="https://github.com/tklocek/SwiftStash/actions/workflows/tests.yml"><img src="https://img.shields.io/github/actions/workflow/status/tklocek/SwiftStash/tests.yml?branch=main&style=flat-square&label=Tests" alt="Tests"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-MIT-blue?style=flat-square" alt="License"></a>
  <a href="https://tklocek.github.io/SwiftStash/documentation/"><img src="https://img.shields.io/badge/Documentation-DocC-34C759?style=flat-square&logo=swift&logoColor=white" alt="Documentation"></a>
</p>

<p align="center">
  <a href="https://tklocek.github.io/SwiftStash/documentation/">Documentation</a> ·
  <a href="#quick-start">Quick Start</a> ·
  <a href="https://tklocek.github.io/SwiftStash/documentation/swiftstash/migratingfromappstorage">Migrating from @AppStorage</a> ·
  <a href="#example-app--templates">Example App</a>
</p>

```swift
import SwiftStash                                             // Foundation-only, no SwiftUI

final class Session {
    @Stash("username") var username: String = ""              // UserDefaults — reads like @AppStorage
    @Stash(codable: "profile") var profile = Profile()        // any Codable — @AppStorage can't
    @SecureStash(key: "authToken") var authToken: String?     // Keychain — same property syntax
}

struct SettingsView: View {                                   // and in SwiftUI: import SwiftStashUI
    @Stashed("theme") var theme: Theme = .system              // re-renders the view on change
}
```

> **Status: 0.1.0** — the API is functional and covered by automated tests, but may still change before 1.0. Feedback and issues are very welcome.

## Why SwiftStash instead of `@AppStorage`?

`@AppStorage` works great — until you hit one of these walls. Each row is something `@AppStorage` **cannot do** and SwiftStash can:

| You need to… | `@AppStorage` | SwiftStash |
|---|---|---|
| Persist outside SwiftUI | ❌ Requires SwiftUI | ✅ `@Stash` is pure Foundation |
| Store a custom struct | ❌ Plist primitives + enums only | ✅ `@Stash(codable:)` stores any `Codable` |
| Keep a secret (token, password) | ❌ Plain-text UserDefaults | ✅ `@SecureStash` uses the Keychain |
| Share state as a `static let` under Swift 6 | ❌ Not a `Sendable` primitive | ✅ Core wrappers are `Sendable` |
| React to changes from *anywhere* | ❌ Only re-renders its own view | ✅ Per-key `AsyncStream` |
| Catch unstorable types early | ❌ Runtime exception | ✅ Compile error |
| Tell "never set" from "default" | ❌ Impossible | ✅ `$property.exists` |

**And there is no persisted-data migration for compatible values.** `@Stash` and `@Stashed` use the same storage representation as `@AppStorage`, so existing primitive and raw-representable values are picked up as-is — convert one property at a time. If you never hit any wall above, keep using `@AppStorage`.

<details>
<summary><b>How does this compare to Defaults or KeychainAccess?</b></summary>

Both are excellent libraries, and if you only need one half of the problem they remain great choices. SwiftStash's angle is the *combination*:

- **One library, one syntax, both stores.** `@Stash` (UserDefaults) and `@SecureStash` (Keychain) share the same property-wrapper shape, typed-key support, logging, and one configuration entry point.
- **`@AppStorage` wire compatibility.** [Defaults](https://github.com/sindresorhus/Defaults) uses its own bridge-based encoding; SwiftStash deliberately stores values exactly as `@AppStorage` does, so adoption is incremental with no data migration.
- **Swift 6 strictness as a baseline.** Strict memory safety; `Stash` and `SecureStash` are `Sendable` with `nonmutating set`, usable as `static let` under strict concurrency.
- **Compile-time plist checking.** Non-storable types (including `[URL]` and optionals inside collections) are compile errors, not runtime exceptions.

If you need [KeychainAccess](https://github.com/kishikawakatsumi/KeychainAccess)-level control over every keychain attribute, use it — `@SecureStash` intentionally trades exhaustiveness for a property-wrapper API plus `KeychainManager` for typed-error access.

</details>

## Installation

Add SwiftStash to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/tklocek/SwiftStash.git", from: "0.1.0")
]
```

Or in Xcode: **File → Add Package Dependencies…**, paste the repository URL, and add the `SwiftStash` library (plus `SwiftStashUI` if you want `@Stashed`) to your target.

## Quick Start

### `@Stash` — UserDefaults

```swift
import SwiftStash

final class UserSettings {
    @Stash("username") var username: String = ""              // primitives — reads like @AppStorage
    @Stash("lastLoginDate") var lastLoginDate: Date?          // optionals — nil removes the key
    @Stash("theme") var theme: Theme = .system                // enums — stored as the raw value
    @Stash(codable: "userProfile") var userProfile = UserProfile()  // any Codable — stored as JSON
}
```

Works in view models, services, and non-UI packages — no SwiftUI import. The projected value answers what the wrapped value can't: `$username.exists`, `$username.remove()`, and `$username.updates` (a typed `AsyncStream` that fires on writes from any source).

### `@Stashed` — SwiftUI

A `DynamicProperty` replacement for `@AppStorage` — rename the attribute, nothing else changes. The view re-renders on changes from anywhere, including `@Stash` and raw `UserDefaults` writes to the same key:

```swift
import SwiftStashUI

struct SettingsView: View {
    @Stashed("theme") var theme: Theme = .system

    var body: some View {
        Picker("Theme", selection: $theme) {   // projected value is a Binding
            ForEach(Theme.allCases, id: \.self) { Text("\($0)") }
        }
    }
}
```

### `@SecureStash` — Keychain

Same property syntax, backed by the system's data protection keychain. All values are optional; assigning `nil` deletes the item:

```swift
import SwiftStash

// Configure once at app launch
SwiftStash.configureKeychain(
    service: Bundle.main.bundleIdentifier!,
    accessibility: .whenUnlockedThisDeviceOnly
)

@SecureStash(key: "authToken") var authToken: String?
@SecureStash(codable: "credentials") var credentials: Credentials?
```

For what the keychain does and doesn't protect against (and how to report a vulnerability), see [SECURITY.md](SECURITY.md).

## Learn More

The full DocC documentation is published at **[tklocek.github.io/SwiftStash/documentation](https://tklocek.github.io/SwiftStash/documentation/)** and rebuilt from `main` on every push:

| Guide | Covers |
|---|---|
| [Getting Started](https://tklocek.github.io/SwiftStash/documentation/swiftstash/gettingstarted) | Installation, configuration, first wrappers |
| [Migrating from @AppStorage](https://tklocek.github.io/SwiftStash/documentation/swiftstash/migratingfromappstorage) | Incremental adoption with zero data migration |
| [UserDefaults Storage](https://tklocek.github.io/SwiftStash/documentation/swiftstash/userdefaultsstorage) | `@Stash` initialisers, typed keys, projected values, observation |
| [SwiftUI Storage](https://tklocek.github.io/SwiftStash/documentation/swiftstash/swiftuistorage) | `@Stashed` and bindings |
| [Keychain Storage](https://tklocek.github.io/SwiftStash/documentation/swiftstash/keychainstorage) | `@SecureStash`, accessibility, iCloud sync, item classes |
| [Biometrics & Secure Enclave](https://tklocek.github.io/SwiftStash/documentation/swiftstash/keychaincrypto) | Face ID / Touch ID items, hardware-backed keys via `KeychainManager` |
| [Logging](https://tklocek.github.io/SwiftStash/documentation/swiftstash/logging) | Privacy-preserving OSLog integration and log levels |
| [API Reference](https://tklocek.github.io/SwiftStash/documentation/swiftstash/apireference) | Every public symbol |

The project's visual identity is documented in the **[brand book](https://tklocek.github.io/SwiftStash/branding/)**, published from [`Branding/`](Branding/).

## Migrating an Existing App

Migration is incremental and needs **no data migration for compatible values** — old and new code can even run side by side on the same keys:

1. `@AppStorage("key")` in a View → `@Stashed("key")` — rename the attribute, nothing else changes.
2. `@AppStorage` in non-View code → `@Stash("key")` — and drop the SwiftUI dependency.
3. Hand-rolled `UserDefaults` / `SecItem*` code → `@Stash` / `@SecureStash`.

The [migration guide](https://tklocek.github.io/SwiftStash/documentation/swiftstash/migratingfromappstorage) walks through every case, including moving secrets out of UserDefaults.

## Example App & Templates

- [`Example/`](Example/) — an iOS app demonstrating every feature: all wrapper patterns, keychain item classes, cross-instance updates, and logging. Open `Example/SwiftStashExample.xcodeproj` and run the `SwiftStashExample` scheme.
- [`Snippets/`](Snippets/) — small, self-contained usage examples, compiled on every `swift build`, so they always match the current API.
- [`Templates/`](Templates/) — optional Xcode file templates (settings container, credentials store, settings view). Install with `./Templates/install.sh`; see [Templates/README.md](Templates/README.md).

## Requirements

- iOS 14+ / macOS 11+ / tvOS 14+ / watchOS 9+ / visionOS 1+ / Mac Catalyst 14+
- Swift 6.2 toolchain (SPM tools 6.2)
- Apple platforms only — Linux is not supported (the package depends on the Security framework and OSLog)

## Contributing & License

Contributions are welcome — see [CONTRIBUTING.md](CONTRIBUTING.md). Released under the [MIT License](LICENSE).
