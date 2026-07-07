# Migrating from @AppStorage

Adopt SwiftStash in an existing app incrementally — one property at a time, with no data migration.

## Overview

`@Stash` and `@Stashed` use the **exact same storage representation** as `@AppStorage` and raw
`UserDefaults`. Existing persisted values are read as-is, all three wrappers interoperate on the
same keys, and nothing forces a big-bang rewrite: migrate a single property, ship it, and continue
module by module.

### Why migrate at all

`@AppStorage` has seven hard limitations; SwiftStash removes all of them:

1. **SwiftUI-only** — `@AppStorage` needs a SwiftUI import and a `View` context. `@Stash` is pure
   Foundation and works in view models, services, and non-UI packages.
2. **No `Codable`** — `@AppStorage` handles property-list primitives and raw-representable enums
   only. `@Stash(codable:)` stores any `Codable` type.
3. **No secure storage** — secrets stored via `@AppStorage` sit in plain-text UserDefaults.
   ``SecureStash`` is the same property syntax backed by the Keychain.
4. **No static or shared state under Swift 6** — `@AppStorage` is a `DynamicProperty`. `Stash` and
   ``SecureStash`` are `Sendable` with `nonmutating set`, safe as `static let` under strict
   concurrency.
5. **No observation outside its own view** — SwiftStash provides per-key `AsyncStream` updates
   that fire for writes from any source.
6. **Runtime crashes on wrong types** — SwiftStash turns non-plist misuse into a compile error via
   the ``UserDefaultsPrimitiveType`` marker protocol.
7. **Cannot distinguish "never set" from "default"** — the projected `$property.exists` can.

If none of these apply to your app, `@AppStorage` is fine. If any does, follow the steps below.

## Step 1: Add the dependency and configure at launch

Add the package (see <doc:GettingStarted>), then add only the configuration your app needs in
`App.init()` or the app delegate:

```swift
// Only if the app shares settings with extensions via an App Group:
SwiftStash.configureUserDefaults(suiteName: "group.com.example.app")

// Only if any @SecureStash will be used — required before the first wrapper is created:
SwiftStash.configureKeychain(
    service: Bundle.main.bundleIdentifier!,
    accessibility: .whenUnlockedThisDeviceOnly
)

// Optional:
SwiftStash.logLevel = .normal
```

## Step 2: Inventory the existing keys

Search the project for `@AppStorage`, `UserDefaults`, `forKey:`, and any keychain wrapper.
Collect the key strings into one enum, **preserving the exact existing strings**:

```swift
enum SettingsKey: String {
    case username        // was @AppStorage("username")
    case launchCount     // was UserDefaults.standard.integer(forKey: "launchCount")
    case profileData     // was a JSON-encoded blob
}
```

Every SwiftStash initialiser accepts these typed keys directly:
`@Stash(SettingsKey.username) var username = ""`.

> Important: Keys containing dots (`.`) keep working for storage, but cannot be observed with
> `updates` streams — KVO interprets dots as key paths. Rename the key only if you need
> observation and can afford losing the previously stored value.

## Step 3: Convert mechanically

| Existing code | Replacement |
|---------------|-------------|
| `@AppStorage("k") var x: T = d` in a `View` | `@Stashed("k") var x: T = d` — rename the attribute (import `SwiftStashUI`) |
| `@AppStorage` in a non-`View` type | `@Stash("k") var x: T = d` — remove the SwiftUI import if now unused |
| `UserDefaults` get/set pairs | one `@Stash` property |
| JSON blob | `@Stash(codable: "k") var x = d` — pass `encoder:`/`decoder:` if the format used custom strategies |
| enum stored via `rawValue` | `@Stash("k") var x: T = d` — the raw-value format is identical |
| keychain code or third-party keychain library | ``SecureStash`` (optional-typed) or ``KeychainManager`` where thrown errors are needed |

Two conversions need care:

- **Custom coder strategies**: if the persisted format was written with non-default strategies
  (dates, keys), hand the same configured `JSONEncoder`/`JSONDecoder` to the wrapper —
  `@Stash(codable: "k", encoder: encoder, decoder: decoder) var x = d` — so existing
  payloads keep decoding and new writes keep the format.
- **Format boundaries**: switching a key between the primitive and `codable:` initialisers is a
  data-format change — enums are stored as plain raw values, `Codable` types as JSON `Data`.
  Keep whichever format is already on disk.

## Step 4: Move secrets out of UserDefaults

Tokens, passwords, and API keys found in UserDefaults belong in the Keychain. Unlike the
conversions above, this is a real store change and needs a one-time migration:

```swift
@Stash(key: "authToken") var legacyToken: String?          // old location
@SecureStash(key: "authToken") var authToken: String?      // new location

if let token = legacyToken {
    authToken = token          // write to the Keychain
    $legacyToken.remove()      // delete the plain-text copy
}
```

## Step 5: Verify

Build and run the existing settings tests. Watch for the two pitfalls that bite silently:

- The keychain `service` must be configured (or passed per wrapper) **before the first
  `@SecureStash` is created** — instance properties initialise with their container, so configure
  at app launch.
- The library's default keychain accessibility, `.whenPasscodeSetThisDeviceOnly`, makes items
  unreadable on devices without a passcode. For broad consumer apps pass
  `.whenUnlockedThisDeviceOnly` explicitly.

## See Also

- <doc:GettingStarted>
- <doc:UserDefaultsStorage>
- <doc:KeychainStorage>
- <doc:SwiftUIStorage>
