# SwiftStash

[![Swift 6.2](https://img.shields.io/badge/Swift-6.2-F05138?style=flat-square&logo=swift&logoColor=white)](https://www.swift.org/)[![Platforms](https://img.shields.io/badge/Platforms-iOS%20%7C%20macOS%20%7C%20tvOS%20%7C%20watchOS%20%7C%20visionOS%20%7C%20Mac%20Catalyst-0A84FF?style=flat-square&logo=apple&logoColor=white)](#requirements)[![Swift Package Manager](https://img.shields.io/badge/SPM-compatible-F05138?style=flat-square&logo=swift&logoColor=white)](#installation)[![License](https://img.shields.io/badge/License-MIT-blue?style=flat-square)](LICENSE)[![Documentation](https://img.shields.io/badge/Documentation-DocC-34C759?style=flat-square&logo=swift&logoColor=white)](https://tklocek.github.io/SwiftStash/)

Type-safe, property wrapper-based persistence for Swift: UserDefaults, Keychain, and SwiftUI — with built-in privacy-preserving logging.

> **Status: 0.1.0** — the API is functional and covered by automated tests, but may still change before 1.0. Feedback and issues are very welcome.

## Why SwiftStash instead of `@AppStorage`?

`@AppStorage` works great — until you hit one of these walls. Each row is something `@AppStorage` **cannot do** and SwiftStash can:

| You need to… | `@AppStorage` | SwiftStash |
|---|---|---|
| Keep persistence code independent of SwiftUI | ❌ Can be used outside a `View`, but still requires SwiftUI; `DynamicProperty` observation is view-oriented | ✅ `@Stash` is pure Foundation — designed for view models, services, and packages |
| Store a custom struct | ❌ Plist primitives and raw-representable enums only | ✅ `@Stash(codable:)` stores any `Codable`, JSON-encoded transparently |
| Keep a secret (token, password, key) | ❌ Nothing — secrets end up in plain-text UserDefaults | ✅ `@SecureStash` puts them in the Keychain, same property syntax |
| Share persisted state as a `static let` under Swift 6 | ❌ A SwiftUI `DynamicProperty`, not a `Sendable` shared-state primitive | ✅ Core wrappers are `Sendable` and safe as `static let` under strict concurrency |
| React to a value changing from *anywhere* in the app | ❌ Only re-renders its own view | ✅ Per-key `AsyncStream` fires for writes from any source |
| Reject a value type UserDefaults cannot store | ❌ Fails at runtime, potentially with `NSInvalidArgumentException` | ✅ Compile error |
| Tell "never set" apart from "set to the default" | ❌ Impossible | ✅ `$property.exists` |

**And there is no persisted-data migration for compatible values.** `@Stash` and `@Stashed` use the same storage representation as `@AppStorage`, so existing primitive and raw-representable values are picked up as-is. Convert one property at a time; inside views, `@Stashed` keeps the familiar declaration and binding syntax while re-rendering on changes. If you never hit any wall above, keep using `@AppStorage`.

### How does this compare to Defaults or KeychainAccess?

Both are excellent libraries, and if you only need one half of the problem they remain great choices. SwiftStash's angle is the *combination*:

- **One library, one syntax, both stores.** `@Stash` (UserDefaults) and `@SecureStash` (Keychain) share the same property-wrapper shape, the same typed-key support, the same logging, and one configuration entry point. Moving a value between the two stores is a one-line change of wrapper.
- **`@AppStorage` wire compatibility.** [Defaults](https://github.com/sindresorhus/Defaults) uses its own bridge-based encoding; SwiftStash deliberately stores values exactly as `@AppStorage` does, so you can adopt it incrementally in an existing app (or read the same keys from both) with no data migration.
- **Swift 6 strictness as a baseline.** Built in Swift 6 language mode with strict memory safety; the core wrappers `Stash` and `SecureStash` are `Sendable` with `nonmutating set`, usable as `static let` under strict concurrency.
- **Compile-time plist checking.** Non-storable types (including `[URL]` and optionals inside collections) are compile errors, not runtime exceptions.

If you need [KeychainAccess](https://github.com/kishikawakatsumi/KeychainAccess)-level control over every keychain attribute, use it — `@SecureStash` intentionally trades exhaustiveness for a property-wrapper API plus `KeychainManager` for typed-error access.

## Modules

| Module | Import | Provides |
|--------|--------|----------|
| `SwiftStash` | Foundation only | `@Stash` (UserDefaults), `@SecureStash` (Keychain), per-key observation, logging |
| `SwiftStashUI` | SwiftUI | `@Stashed` — a `DynamicProperty` that re-renders views on changes |

## Features

- 🎯 **Type-safe values** — non-plist types are compile errors, not runtime crashes; typed keys are available when you want them
- 🔄 **Property wrappers** — `@Stash`, `@SecureStash`, `@Stashed`
- 📦 **Codable support** — store any Codable type, JSON-encoded transparently
- 🏷️ **Enum support** — `RawRepresentable` values stored as their plain raw value, interoperable with `@AppStorage`
- 🔑 **Typed keys** — use a string-backed key enum instead of raw strings
- 👁️ **Per-key observation** — `AsyncStream` updates for any key, firing on writes from anywhere
- 🔐 **Keychain storage** — `@SecureStash` with accessibility, iCloud sync, and item class control
- 🧬 **Biometrics & Secure Enclave** — `KeychainManager` with caller-owned `LAContext` reads and hardware-backed key pairs
- 🧵 **Swift 6 ready** — `Sendable` wrappers, safe as `static let` under strict concurrency
- 🪵 **Built-in logging** — privacy-preserving OSLog integration
- ⚡ **Zero dependencies** — pure Swift, only Apple system frameworks (Foundation, Security, OSLog)

## Documentation

The full DocC documentation is published at **[tklocek.github.io/SwiftStash](https://tklocek.github.io/SwiftStash/)** and rebuilt from `main` on every push. One site covers both modules:

- [SwiftStash](https://tklocek.github.io/SwiftStash/documentation/swiftstash/) — `@Stash`, `@SecureStash`, observation, logging, keychain & crypto, plus articles (getting started, migrating from `@AppStorage`)
- [SwiftStashUI](https://tklocek.github.io/SwiftStash/documentation/swiftstashui/) — `@Stashed`

## Quick Start

### `@Stash` — UserDefaults

```swift
import SwiftStash

final class UserSettings {
    // Primitive types — reads exactly like @AppStorage
    @Stash("username") var username: String = ""

    // Optional values (no default needed; assigning nil removes the key)
    @Stash("lastLoginDate") var lastLoginDate: Date?

    // Enums (RawRepresentable) — stored as the plain raw value
    @Stash("theme") var theme: Theme = .system

    // Codable types — JSON-encoded; @AppStorage can't do this at all
    @Stash(codable: "userProfile") var userProfile = UserProfile()
}

let settings = UserSettings()
settings.username = "john_doe"
print(settings.username)  // "john_doe"
```

`@Stash` is `Sendable` and its setter is `nonmutating`, so it also works in immutable and static contexts:

```swift
enum AppState {
    static let logLevel = Stash(key: "logLevel", defaultValue: "normal")
}

AppState.logLevel.wrappedValue = "verbose"   // fine under Swift 6 strict concurrency
```

The `@Stash … static var` attribute spelling also works, as long as the containing type is actor-isolated (e.g. `@MainActor`) — Swift 6 rejects wrapped static vars in nonisolated types.

### `@Stashed` — SwiftUI

A `DynamicProperty` replacement for `@AppStorage`. The view re-renders when the value changes — including writes made elsewhere through `@Stash`, `@AppStorage`, or raw `UserDefaults`, because both wrappers share the same storage representation.

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

All values are optional; assigning `nil` deletes the item.

```swift
import SwiftStash

// Configure once at app launch
SwiftStash.configureKeychain(
    service: Bundle.main.bundleIdentifier!,
    accessibility: .whenUnlockedThisDeviceOnly
)

@SecureStash(key: "authToken")
var authToken: String?

@SecureStash(codable: "credentials")
var credentials: Credentials?

@SecureStash(key: "password", itemClass: .internetPassword(domain: "api.example.com"))
var apiPassword: String?
```

Items go to the system's **data protection keychain** on every platform (including macOS), encrypted at rest and gated by the configured accessibility level. The default accessibility is `.whenPasscodeSetThisDeviceOnly` — maximum protection, but unreadable on devices without a passcode; broad consumer apps should pass `.whenUnlockedThisDeviceOnly` explicitly, as above. For what the keychain does and doesn't protect against (and how to report a vulnerability), see [SECURITY.md](SECURITY.md).

### Biometrics & Secure Enclave — `KeychainManager`

For items behind Face ID / Touch ID and for hardware-backed cryptographic keys, `KeychainManager` adds a typed-error API on top of the same primitives. Authentication is always caller-owned: you evaluate the `LAContext`, the package never prompts on its own.

```swift
import LocalAuthentication

let keychain = KeychainManager(service: Bundle.main.bundleIdentifier!)

// Item readable only after user presence (Face ID / Touch ID / passcode)
try keychain.saveBiometric(
    Data("secret".utf8),
    for: "authToken",
    with: .genericPassword,
    accessibility: .whenUnlockedThisDeviceOnly,
    flags: [.userPresence]
)

let context = LAContext()
try await context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: "Unlock")
let secret = try keychain.loadBiometric(for: "authToken", with: .genericPassword, authenticationContext: context)

// P-256 key pair whose private half never leaves the Secure Enclave
let publicKey = try keychain.generateKey(
    descriptor: CryptoKeyDescriptor(stringTag: "com.example.signing", algorithm: .ec),
    keySizeInBits: 256,
    storage: .secureEnclave(accessibility: .whenUnlockedThisDeviceOnly, flags: [.privateKeyUsage])
)

// Existence checks that never trigger a biometric prompt
keychain.exists(for: "authToken", with: .genericPassword)
keychain.existsKey(CryptoKeyDescriptor(stringTag: "com.example.signing"))
```

Biometric writes use the delete-then-add pattern (a `SecItemUpdate` would force a re-prompt — the API makes that mistake impossible), and the Secure Enclave accepts EC P-256 only; asking it for RSA throws `KeychainError.secureEnclaveAlgorithmInvalid`. These APIs need the LocalAuthentication framework, so they're unavailable on tvOS — calling them there is a compile-time error with an explanatory message, not a missing symbol.

## Initialisers

Every form has two equivalent spellings. The `@AppStorage`-style spelling — positional key, default as the assignment — is the recommended one; it keeps migrated code reading exactly as it did before:

| Value type | `@AppStorage`-style (recommended) | Labelled equivalent |
|---|---|---|
| Plist primitive | `@Stash("count") var count = 0` | `@Stash(key: "count", defaultValue: 0)` |
| Enum (plist raw value) | `@Stash("theme") var theme: Theme = .system` | `@Stash(key: "theme", defaultValue: Theme.system)` |
| Any other `Codable` | `@Stash(codable: "profile") var profile = Profile()` | `@Stash(codable: "profile", defaultValue: Profile())` |
| Optional (any of the above) | `@Stash("lastLogin") var lastLogin: Date?` | `@Stash(key: "lastLogin")` |

`@Stashed` mirrors the same spellings. The labelled form is what you use when there is no assignment to hang the default on — most notably direct instantiation (`Stash(key: "logLevel", defaultValue: "normal")` as a `static let`). The `codable:` initialisers additionally accept an `encoder:`/`decoder:` pair for non-default JSON strategies.

## Typed Keys

Every initialiser also accepts a string-backed key type, so a single enum can own all your keys:

```swift
enum SettingsKey: String {
    case username, theme, userProfile
}

@Stash(SettingsKey.username) var username = ""

@Stashed(SettingsKey.theme) var theme: Theme = .system

@SecureStash(key: SettingsKey.username) var secureName: String?
```

## Projected Value: `$property`

`@Stash` projects a `StashHandle` for the questions the wrapped value can't answer:

```swift
@Stash("launchCount") var launchCount = 0

$launchCount.exists      // false until something is written —
                         // distinguishes "stored default" from "nothing stored"
$launchCount.remove()    // deletes the key; reads fall back to the default
$launchCount.key         // "launchCount"

// Typed change stream: yields the current value, then every change
for await count in $launchCount.updates {
    print("launchCount is now \(count)")
}
```

`@SecureStash` projects a `SecureStashHandle` with the same shape, minus `updates` (the keychain has no change-notification mechanism):

```swift
@SecureStash(key: "authToken") var authToken: String?

$authToken.exists      // presence probe — no read, no decode
$authToken.remove()    // deletes the item; same effect as authToken = nil
$authToken.key         // "authToken"
```

(`@Stashed` projects a `Binding` instead, for `Picker`/`Toggle`/`TextField`.)

## Observing Keys

Any key can be observed without a property wrapper:

```swift
Task {
    for await _ in SwiftStash.updates(forKey: "logLevel") {
        syncLogLevel()
    }
}
```

Observation is per-key KVO: it fires only for that key, and catches writes from any source. Note that KVO cannot observe keys containing dots (`.`), because they are interpreted as key paths.

## Configuration

Configure once at app launch — each subsystem independently, only what you use:

```swift
// Custom UserDefaults suite (e.g. App Groups) for all @Stash/@Stashed properties
SwiftStash.configureUserDefaults(suiteName: "group.com.example.app")

// Keychain defaults for all @SecureStash properties
SwiftStash.configureKeychain(
    service: Bundle.main.bundleIdentifier!,
    accessibility: .whenUnlockedThisDeviceOnly
)

// Logging
SwiftStash.logLevel = .normal
```

Individual wrappers can override globals with explicit `userDefaults:`/`store:` or keychain parameters.

## Logging

SwiftStash includes privacy-preserving logging to help you debug and monitor storage operations.

### Log Levels (`StashLogLevel`)

| Level | Description | Use Case |
|-------|-------------|----------|
| `.minimal` | Errors only (default) | ✅ Production builds |
| `.normal` | Errors + storage operations | 🔍 Debugging |
| `.verbose` | Everything including encoding/decoding | 🛠️ Development only |

```swift
SwiftStash.logLevel = .verbose        // development
print(SwiftStash.logLevel)            // Verbose
```

### What Gets Logged?

- ✅ **Keys**: logged as `.private` (redacted in system logs)
- ✅ **Type names**: logged as `.public` (visible for debugging)
- ✅ **Operations**: GET, SET, REMOVE (UserDefaults); SAVE, UPDATE, DELETE (Keychain)
- ✅ **Errors**: encoding/decoding failures with details

**Example log output (`.normal` level):**
```
SwiftStash: GET [key: <private>, type: String]
SwiftStash: SET [key: <private>, type: Int]
```

Encoding and decoding messages appear at `.verbose` level.

## Adopting SwiftStash in an Existing App

Migration is incremental and requires **no data migration for compatible values** — `@Stash`/`@Stashed` use the same storage representation as `@AppStorage` and raw `UserDefaults` for supported primitive and raw-representable values. You can convert one property at a time; old and new code can even run side by side on the same keys.

| You have | Replace with | Notes |
|----------|--------------|-------|
| `@AppStorage("key") var x: T = d` in a View | `@Stashed("key") var x: T = d` | Rename the attribute — nothing else changes |
| `@AppStorage` in non-View code | `@Stash("key") var x: T = d` | Removes the SwiftUI dependency from that file or target |
| `UserDefaults.standard.object(forKey:)` + casts | `@Stash` | The property's value type and supported storage format are checked at compile time |
| Manually JSON-encoded structs in UserDefaults | `@Stash(codable:defaultValue:)` | Same wire format; pass `encoder:`/`decoder:` if your format used custom strategies |
| Hand-rolled `SecItem*` keychain code | `@SecureStash` | One property instead of ~40 lines of query dictionaries |
| Keychain wrapper libraries (KeychainAccess etc.) | `@SecureStash` / `KeychainManager` | Zero dependencies; typed `KeychainError` |

A typical adoption sequence:

1. Add the package and call the `configure…` functions once at app launch.
2. Define a key enum (`enum SettingsKey: String { … }`) listing your existing UserDefaults keys — keep the exact same strings.
3. Convert properties module by module: `@Stashed` in views, `@Stash` everywhere else.
4. Move secrets that ended up in UserDefaults into `@SecureStash` (this one *is* a store change — read the old value once, write it to the keychain, remove the old key).

## Type Safety

Only property-list types can use the primitive initialiser — enforced at compile time by the `UserDefaultsPrimitiveType` marker protocol (`String`, `Int`, `Double`, `Float`, `Bool`, `Data`, `Date`, `URL`, plus arrays and string-keyed dictionaries thereof). Similarly, `RawRepresentable` stashes require a property-list raw value. Anything else must use the `codable:` initialiser — misuse is a compile error instead of an `NSInvalidArgumentException` at runtime.

Collections are checked one level deeper: `URL` and optionals are storable at the top level only (UserDefaults rejects them *inside* collections at runtime), so `[URL]` and `[String?]` are compile errors too — use `@Stash(codable:)` for those.

## Example App

SwiftStash includes a comprehensive example app demonstrating all features:

```bash
# Open the example app project
open Example/SwiftStashExample.xcodeproj

# In Xcode, select "SwiftStashExample" scheme and press ⌘R
```

The example app showcases:
- ✅ All @Stash patterns (primitives, optionals, enums, Codable types)
- ✅ All @SecureStash patterns (keychain storage, different item classes)
- ✅ @Stashed in SwiftUI with cross-instance updates
- ✅ Logging configuration
- ✅ Real-world usage examples

## Installation

### Swift Package Manager

Add SwiftStash to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/tklocek/SwiftStash.git", from: "0.1.0")
]
```

> `from: "0.1.0"` selects stable releases from `0.1.0` up to, but not including, `1.0.0`.

Or in Xcode:
1. File → Add Package Dependencies
2. Enter the repository URL
3. Select version and add to your target

### Snippets

The [`Snippets/`](Snippets/) directory contains small, self-contained usage examples (settings container, credentials store, observation, SwiftUI form). They are Swift Package Manager snippets, compiled on every `swift build`, so they always match the current API.

### Xcode File Templates (Optional)

SwiftStash includes optional Xcode file templates for the three most common starting points:

- **SwiftStash Settings** — creates a Foundation-only `@Stash` settings container.
- **SwiftStash Credentials Store** — creates an `@SecureStash` token store with an explicit Keychain service.
- **SwiftStash Settings View** — creates a SwiftUI `Form` bound directly to `@Stashed`.

Use them when you want a compile-ready structure with typed keys and safe defaults instead of repeatedly assembling the same imports, wrappers, and container types by hand. The generated file is ordinary Swift code; rename the example property and add the values your app needs.

Templates are **not installed automatically** when SwiftStash is added through Swift Package Manager. Package dependencies cannot write into your home directory, so installation requires an explicit action from the current macOS user:

```bash
git clone https://github.com/tklocek/SwiftStash.git
cd SwiftStash
./Templates/install.sh
```

The script copies the templates to `~/Library/Developer/Xcode/Templates/File Templates/SwiftStash/`. Restart Xcode, then choose **File → New → File** and open the **SwiftStash** section.

To update the templates, pull the latest repository changes and run `./Templates/install.sh` again. To remove only the templates installed by SwiftStash:

```bash
./Templates/uninstall.sh
```

See [Templates/README.md](Templates/README.md) for the complete template list and installation details.

## Development

### Working on SwiftStash

```bash
# Open the example app project
open Example/SwiftStashExample.xcodeproj

# Select the SwiftStashExample scheme to run the example iOS app.
# The project references the local package automatically.

# Or from the command line:
swift build
swift test
```

Working with an AI coding agent? Point it at `AGENTS.md` — it covers the API decision table, common pitfalls, and repo conventions.

## Requirements

- iOS 14+ / macOS 11+ / tvOS 14+ / watchOS 9+ / visionOS 1+ / Mac Catalyst 14+
- Swift 6.2 (tools 6.2)
- Xcode 26+ (ships the Swift 6.2 toolchain)
- Apple platforms only — Linux is not supported (the package depends on the Security framework and OSLog)

## License

MIT License - see LICENSE file for details
