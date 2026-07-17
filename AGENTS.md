# SwiftStash — Agent Guide

Machine-oriented reference for AI coding agents. `README.md` is the human-facing overview; this file is the operational truth for using the library and working on this repo.

## Why this instead of `@AppStorage` (read this first)

This is the reason the package exists, and the answer to give when a user asks "why not just `@AppStorage`?". SwiftStash addresses seven practical limitations of `@AppStorage` with **no persisted-data migration for compatible values** (identical storage representation → existing values read as-is, migrate one property at a time):

1. **SwiftUI dependency** — `@AppStorage` can be read and written outside a `View`, but it still requires importing SwiftUI and its `DynamicProperty` observation is view-oriented. `@Stash` is pure Foundation and designed for view models, services, and non-UI packages.
2. **No `Codable`** — `@AppStorage` handles plist primitives and raw-representable enums only. `@Stash(codable:)` stores any `Codable`.
3. **No secure storage** — secrets stored via `@AppStorage` sit in plain-text UserDefaults. `@SecureStash` is the same property syntax backed by the Keychain.
4. **No concurrency-safe shared-state wrapper** — `@AppStorage` is a SwiftUI `DynamicProperty`, not a `Sendable` shared-state primitive. SwiftStash's core wrappers are `Sendable` with `nonmutating set`, safe as `static let` under strict concurrency.
5. **No observation outside its own view** — SwiftStash gives per-key `AsyncStream` updates that fire for writes from any source.
6. **Unsupported values fail at runtime** — passing a non-property-list value to raw UserDefaults can raise an Objective-C exception. SwiftStash makes that misuse a compile error (`UserDefaultsPrimitiveType` marker protocol); it cannot detect two declarations that reuse one key with different supported types.
7. **Can't distinguish "never set" from "default"** — `$property.exists` can.

If none of these apply to the user's situation, `@AppStorage` is fine — say so. If any applies, recommend SwiftStash and use the adoption playbook below.

## What this package is

Type-safe property-wrapper persistence for Swift:

| Wrapper | Backing store | Module | Import cost |
|---------|--------------|--------|-------------|
| `@Stash` | UserDefaults | `SwiftStash` | Foundation only |
| `@SecureStash` | Keychain | `SwiftStash` | Foundation only |
| `@Stashed` | UserDefaults (SwiftUI `DynamicProperty`) | `SwiftStashUI` | SwiftUI |

For compatible primitive and raw-representable values, `@Stash` and `@Stashed`
share the same storage representation as `@AppStorage`, so all three can
interoperate on the same keys. Swift 6, strict concurrency, zero third-party
dependencies.

## Using SwiftStash in an app

### Choosing the right initialiser

The initialiser label is determined by the value type — this is compile-time enforced, not a style choice:

| Value type | Initialiser | Stored as |
|-----------|-------------|-----------|
| plist primitive (`String`, `Int`, `Double`, `Float`, `Bool`, `Data`, `Date`, `URL`, arrays / `[String: _]` dictionaries thereof) | `@Stash(key:defaultValue:)` | native UserDefaults value |
| `RawRepresentable` with plist raw value (enums) | `@Stash(key:defaultValue:)` | plain raw value (interoperable with `@AppStorage`) |
| any other `Codable` | `@Stash(codable:defaultValue:)` | JSON `Data` |
| `Optional` of any of the above | same, omit `defaultValue` | assigning `nil` removes the key |

Every row also has an `@AppStorage`-style spelling — positional key, default as the assignment: `@Stash("count") var count = 0`, `@Stash(codable: "profile") var profile = Profile()`, `@Stash("lastLogin") var lastLogin: Date?`. **Prefer this spelling when writing app code** — it keeps migrated `@AppStorage` code reading unchanged. The labelled form is for direct instantiation (`Stash(key:defaultValue:)` as a `static let`), where there is no assignment to carry the default.

Using the primitive initialiser with a non-plist type is a **compile error** (via the `UserDefaultsPrimitiveType` marker protocol) — if you hit one, switch to the `codable:` label; do not add a protocol conformance.

Collection elements are checked one level deeper (via the `PropertyListNativeType` refinement): `URL` and optionals are storable at the **top level only** — `[URL]`, `[String: URL]`, and `[String?]` are compile errors because UserDefaults rejects them inside collections at runtime. Use `@Stash(codable:)` for those.

### Core patterns

```swift
import SwiftStash

// One-time app-launch configuration (each line optional, only what you use)
SwiftStash.configureUserDefaults(suiteName: "group.com.example.app") // App Groups
SwiftStash.configureKeychain(
    service: Bundle.main.bundleIdentifier!,      // REQUIRED before any @SecureStash without explicit service
    accessibility: .whenUnlockedThisDeviceOnly
)
SwiftStash.logLevel = .normal                    // .minimal (default) / .normal / .verbose

final class Settings {
    @Stash("username") var username: String = ""
    @Stash("lastLogin") var lastLogin: Date?                  // optional: nil removes key
    @Stash("theme") var theme: Theme = .system                // enum → raw value
    @Stash(codable: "profile") var profile = Profile()        // any Codable → JSON Data
    @Stash("launchCount") var launchCount: Int = 0
}

// Static/shared state under Swift 6 strict concurrency (Sendable, nonmutating set).
// In a nonisolated type, hold the wrapper as a `static let` and use .wrappedValue —
// the `@Stash … static var` attribute spelling is a compile error there (the
// synthesized backing storage is nonisolated global mutable state):
enum AppState {
    static let logLevel = Stash(key: "logLevel", defaultValue: "normal")
    // read/write via AppState.logLevel.wrappedValue
}
// The attribute spelling on `static var` works inside an actor-isolated type:
@MainActor enum AppSettings {
    @Stash("theme") static var theme: String = "system"
}
```

Typed keys: every initialiser also accepts any `RawRepresentable<String>` key (`@Stash(SettingsKey.username) var username = ""`; labelled: `@Stash(key: SettingsKey.username, defaultValue: "")`).

Parameter-label asymmetry is intentional — don't "fix" it: `Stash` calls the store `userDefaults:` (the Foundation-side name), while `@Stashed` uses `store:` (mirrors `@AppStorage`) and `SwiftStash.updates(forKey:in:)` uses `in:` (reads naturally at the call site).

### Projected values

- `@Stash` projects `StashHandle`: `$prop.exists` (distinguishes stored-default from nothing-stored), `$prop.remove()`, `$prop.key`, `$prop.updates` (typed `AsyncStream`: current value, then every change).
- `@Stashed` projects a SwiftUI `Binding` (for `Picker`/`Toggle`/`TextField`).
- `@SecureStash` projects `SecureStashHandle`: `$prop.exists` (presence probe — no decode, so an undecodable payload still reports `true`), `$prop.remove()` (same as assigning `nil`), `$prop.key`. No `updates` stream — the keychain has no change-notification mechanism.

### Observation

```swift
for await value in $launchCount.updates { ... }          // typed, via projected value
for await _ in SwiftStash.updates(forKey: "logLevel") { ... }  // any key, no wrapper needed
```

Per-key KVO under the hood: fires for writes from any source (`@Stash`, `@AppStorage`, raw UserDefaults).

Initial-value semantics differ between the two: `$prop.updates` yields the **current value immediately**, then every change; `SwiftStash.updates(forKey:)` yields **only on change** — no initial element. When consuming the latter to keep state in sync, read the value once before starting the loop.

Both streams default to `.bufferingNewest(1)`: bursts of writes coalesce and a slow consumer sees only the latest state — right for state sync. Callers that need every intermediate element pass an explicit policy: `$prop.updates(bufferingPolicy: .unbounded)` / `SwiftStash.updates(forKey:in:bufferingPolicy:)`.

### Keychain (`@SecureStash`)

```swift
@SecureStash(key: "authToken") var authToken: String?                 // String? / Data?
@SecureStash(codable: "credentials") var credentials: Credentials?   // any Codable, JSON-encoded
@SecureStash(key: "password", itemClass: .internetPassword(domain: "api.example.com"))
var apiPassword: String?
```

- Values are **always optional** — non-optional keychain values are unsupported by design. Assigning `nil` deletes the item.
- Per-wrapper overrides for `service:`, `accessibility:`, `isSynchronizable:`, `itemClass:` beat globals.
- Reads/writes never throw from the wrapper — failures are logged (OSLog) and reads return `nil`.
- Items live in the **data protection keychain** on every platform (`kSecUseDataProtectionKeychain`), so `accessibility` is honored on macOS too. On macOS the app must be signed with an application identifier (any normally signed app qualifies; bare unsigned binaries get `errSecMissingEntitlement`).
- **Lookups match any synchronizable state**: reads, deletes, updates, `exists`, and `allKeys` find an item whether or not it was saved as synchronizable; only `save` writes the exact flag.
- **Writes re-apply the wrapper's accessibility**: updating an existing item propagates an accessibility change made in code — items created by older app versions converge on the current setting at their next write.
- Batch/introspection helpers: `SecureStashHelpers.exists(key:service:)`, `.allKeys(service:)`, `.clearAll(service:itemClass:)` (synchronous, returns the number of deleted items as a `@discardableResult`; password item classes only).
- Lower-level instance API with typed `throws(KeychainError)` on every method: `KeychainManager` (save/load/update/delete), for callers that need error handling instead of wrapper semantics. `update` takes an optional `accessibility:` (nil = leave stored accessibility unchanged). CRUD routes through the same swappable `KeychainBackend` as `@SecureStash`, so `runWithMockBackend` covers it in tests; only the crypto extensions talk to SecItem directly.
- `service` namespaces `.genericPassword` items but is **not** a Keychain access group. The package does not expose `kSecAttrAccessGroup`; a shared service alone cannot share items between an app and extension. For `.internetPassword` the service is ignored entirely — identity is account + domain (carried by the item class).

### Biometrics & Secure Enclave (`KeychainManager` crypto surface)

Lives in `Sources/SwiftStash/Keychain/Crypto/`; defined by `KeychainCryptoManagerProtocol` (deliberately **separate** from `KeychainManagerProtocol` so CRUD mocks aren't forced to implement crypto). Unavailable on tvOS — surfaced there as `@available(*, unavailable)` stubs with an explanatory message, not silently missing symbols (see pitfall 13); this dependency on LocalAuthentication is also why the package's watchOS minimum is 9.

```swift
let keychain = KeychainManager(service: Bundle.main.bundleIdentifier!)

// Biometric item: write is delete-then-add; read needs a caller-satisfied LAContext
try keychain.saveBiometric(data, for: "authToken", with: .genericPassword,
                           accessibility: .whenUnlockedThisDeviceOnly, flags: [.userPresence])
let secret = try keychain.loadBiometric(for: "authToken", with: .genericPassword,
                                        authenticationContext: satisfiedContext)

// Secure Enclave key pair (EC P-256 only); returns the public SecKey
let publicKey = try keychain.generateKey(
    descriptor: CryptoKeyDescriptor(stringTag: "com.example.signing", algorithm: .ec),
    keySizeInBits: 256,
    storage: .secureEnclave(accessibility: .whenUnlockedThisDeviceOnly, flags: [.privateKeyUsage]))

// Prompt-free probes; algorithm-agnostic when descriptor.algorithm == nil
keychain.exists(for: "authToken", with: .genericPassword)   // LAContext(interactionNotAllowed) probe
keychain.existsKey(CryptoKeyDescriptor(stringTag: "com.example.signing"))
try keychain.deleteKey(CryptoKeyDescriptor(stringTag: "com.example.signing"))  // idempotent
```

- **Authentication is caller-owned**: every method takes an optional pre-evaluated `LAContext` (`authenticationContext:`, default `nil`) and never prompts on its own — mirrors the `SecItem`/`SecKey` shape (no artificial async).
- Types: `CryptoKeyDescriptor` (tag + optional algorithm), `CryptoKeyAlgorithm` (`.ec`/`.rsa`), `CryptoKeyStorage` (`.secureEnclave(accessibility:flags:)` / `.keychain(accessibility:)`), `SecAccessControlFlags` (OptionSet mirroring `SecAccessControlCreateFlags`).
- `generateKey` **replaces** any existing key under the same tag (any algorithm) and returns the public key; `loadKeyReference` returns the private `SecKey` (opaque ref for SE keys).
- Crypto errors: `interactionRequired`, `accessControlCreationFailed`, `keyGenerationFailed(OSStatus)`, `publicKeyExtractionFailed`, `secureEnclaveAlgorithmInvalid`.

### Use cases → recommended tool

| Use case | Use |
|----------|-----|
| App settings/preferences in a non-UI module or package | `@Stash` |
| Settings bound to SwiftUI controls with live re-render | `@Stashed` (SwiftUIView) + `@Stash` (elsewhere, same key) |
| Auth tokens, API keys, passwords, encryption keys | `@SecureStash` |
| Shared settings across app + extensions | `SwiftStash.configureUserDefaults(suiteName: "group…")` |
| iCloud-synced credentials | `@SecureStash(key:…, isSynchronizable: true)` + syncable accessibility (not `*ThisDeviceOnly`) |
| React to a setting changing anywhere in the app | `SwiftStash.updates(forKey:)` or `$prop.updates` |
| Detect "never set" vs "set to default" | `$prop.exists` |
| Keychain access with explicit error handling | `KeychainManager` |
| Secret readable only after Face ID / Touch ID | `KeychainManager.saveBiometric` / `.loadBiometric` |
| Hardware-backed signing/encryption key | `KeychainManager.generateKey(…, storage: .secureEnclave(…))` |
| Check a biometric item exists without prompting | `KeychainManager.exists(for:with:)` / `.existsKey(_:)` |

### Pitfalls (each of these is enforced or silently bites)

1. **Keychain service is mandatory**: a `@SecureStash` initialised with no `service:` argument and no prior `SwiftStash.configureKeychain(service:)` hits a `fatalError` at wrapper init. Configure at app launch, before any wrapper is created (wrappers as `static let` initialise lazily on first touch, but instance properties initialise with their container).
2. **Default keychain accessibility is `.whenPasscodeSetThisDeviceOnly`** — most secure, but items are *unreadable on devices without a passcode*. For broad consumer apps pass `.whenUnlockedThisDeviceOnly` explicitly.
3. **Keys containing dots (`.`) cannot be observed** — KVO interprets them as key paths. Storage works; `updates` streams don't fire. Use dot-free keys if observation is needed.
4. **Enums are stored as raw values**, not JSON — reading the same key with `@AppStorage` works; switching a key between `codable:` and primitive initialisers is a data-format change.
5. **No compat `typealias LogLevel = StashLogLevel`** — deliberate decision (module/type shadowing collision). Don't add one.
6. **Bare dot-syntax keys (`Stash(key: .foo)`) are impossible** with the generic `some RawRepresentable<String>` parameters; consuming apps keep a thin concrete extension if they want that spelling (see `Stash+CustomKeys.swift` pattern).
7. **`isSynchronizable: true` + any `*ThisDeviceOnly` accessibility is invalid** — iCloud Keychain cannot sync device-only items. The wrapper asserts in debug builds and logs an error; in release, writes fail at the SecItem layer.
8. **`URL` and optionals cannot live inside collections** — `[URL]`, `[String: URL]`, `[String?]` are compile errors (`PropertyListNativeType`); use `@Stash(codable:)`.
9. **A failed `Codable` encode keeps the previously stored value** — `@Stash(codable:)` logs the error and leaves the last known-good data in place rather than deleting the key.
10. **There is no `update` for biometric items** — `saveBiometric` always deletes then adds, because `SecItemUpdate` on a `kSecAttrAccessControl` item forces a re-prompt. Don't add an update path.
11. **Secure Enclave accepts EC P-256 only** — `.secureEnclave` + `.rsa` throws `secureEnclaveAlgorithmInvalid` before touching the keychain; SE also requires real hardware (simulator → `keyGenerationFailed`).
12. **Key-usage prompts fire at use, not at load** — `loadKeyReference` returns without authentication; user-presence flags are enforced when the `SecKey` is used (e.g. `SecKeyCreateSignature`). Pass a satisfied `LAContext` to reuse a confirmation.
13. **Crypto/biometric APIs are compile-time unavailable on tvOS** — the real implementations sit behind `#if canImport(LocalAuthentication)`, and `KeychainCrypto+Unavailable.swift` declares `@available(*, unavailable, message:)` stubs so tvOS callers get "requires the LocalAuthentication framework" instead of a bare "no member" error. When adding a crypto method, add its stub there too (LAContext parameters omitted — the type doesn't exist in that SDK).
14. **Data-based keychain writes support password classes only** — `.certificate`, `.key`, and `.identity` cannot be created via `kSecValueData` (SecItem expects `kSecValueRef` for them), so `@SecureStash`/`KeychainManager` writes with those classes fail at the SecItem layer. The cases exist for reading/deleting items created elsewhere.

## Adoption playbook (migrating an existing app to SwiftStash)

When asked to adopt SwiftStash in a consuming app, follow this order. The key property: `@Stash`/`@Stashed` share the exact storage representation with `@AppStorage` and raw `UserDefaults` — **existing persisted values survive, no data migration needed**, and migration can be done incrementally (per property, per module).

1. **Add the dependency** and, at app launch (App.init / AppDelegate), add the needed `configure…` calls: `configureUserDefaults(suiteName:)` only if the app uses App Groups; `configureKeychain(service: Bundle.main.bundleIdentifier!, accessibility: …)` if any `@SecureStash` will be used; `SwiftStash.logLevel` optionally.
2. **Inventory existing keys**: grep for `@AppStorage`, `UserDefaults`, `forKey:`, and any keychain wrapper. Collect the key strings into one `enum SettingsKey: String` — preserve the exact existing strings, including any dots (storage still works with dots; only `updates` observation doesn't).
3. **Convert mechanically**:
   - `@AppStorage("k") var x: T = d` in a View → `@Stashed("k") var x: T = d` — rename the attribute, nothing else changes
   - `@AppStorage` in non-View types → `@Stash("k") var x: T = d` (and remove the SwiftUI import if now unused)
   - `UserDefaults` get/set pairs → one `@Stash` property; JSON-encoded blobs → `@Stash(codable: "k") var x = d`. If the persisted format used custom `JSONEncoder`/`JSONDecoder` strategies (dates, keys), pass the same configured coders via `encoder:`/`decoder:` so existing payloads keep decoding and new writes keep the format.
   - enums stored via `rawValue` → `@Stash("k") var x: T = d` directly (raw-value format is identical)
   - keychain code / keychain libraries → `@SecureStash` (optional-typed) or `KeychainManager` where the caller needs thrown errors
4. **Secrets in the wrong store**: tokens/passwords found in UserDefaults should move to `@SecureStash`. This is a real store change — one-time migration: read old value, write to keychain, `removeObject(forKey:)` the old key.
5. **Verify**: build; if the app has tests over settings, run them. Watch for the pitfalls above (dots + observation, keychain service configured before first wrapper touch).

The motivation for each step is the seven-point list at the top of this file — cite from there when explaining a conversion to the user.

## Working on this repo

### Layout

```
Sources/SwiftStash/            core module (Foundation-only)
  UserDefaults/                @Stash, StashHandle, StashConfiguration, storage impls
  Keychain/                    @SecureStash, KeychainManager, SimpleKeychain (SecItem calls),
                               KeychainBackend (KeychainRuntime.shared swaps live/mock backend)
    Crypto/                    biometric items + SecKey/Secure Enclave APIs (LAContext-based;
                               on tvOS replaced by @available(*, unavailable) stubs)
  Logger/                      OSLog integration, StashLogLevel
Sources/SwiftStashUI/          @Stashed (SwiftUI DynamicProperty), notification-based invalidation
Tests/SwiftStashTests/         Swift Testing, backtick-named tests
Example/                       SwiftStashExample iOS app (not part of the package)
Snippets/                      SPM snippets — compile-checked usage examples (built by swift build)
Templates/                     optional Xcode file templates plus install/uninstall scripts
                               (NOT built by swift build — validated by Templates/check.sh)
Branding/                      brand book (BRANDING.md) + ready SVG logo/lockup assets
SwiftStashExample.xcworkspace  package + example app in one window
```

### Build & test

```bash
swift build          # package + Snippets/ (snippets are compile-checked examples)
swift test           # all tests (Swift Testing; UserDefaults suites are isolated per-test)
./Templates/check.sh # compile the Xcode file templates against the package (they are
                     # NOT built by swift build — run after any public-API change; CI runs it too)
```

Example app (the only compile check for `SwiftStashUI` consumers — build it after touching `SwiftStashUI` or doing repo-wide renames; signing must be disabled, no dev team is configured):

```bash
cd Example && xcodebuild -project SwiftStashExample.xcodeproj \
  -scheme SwiftStashExample -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO CODE_SIGN_IDENTITY="" build
```

### Testing conventions

- Framework is **Swift Testing** (`@Test`, `#expect`), not XCTest. Test names use backticks: `` func `Optional String returns nil when key is absent`() ``.
- UserDefaults tests: use `makeUserDefaults(suiteName:)` from `Tests/SwiftStashTests/Models/TestHelpers.swift` — returns isolated defaults plus a cleanup closure.
- Keychain tests: wrap in `runWithMockBackend { … }`, which swaps `KeychainRuntime.shared` to an in-memory backend — tests never touch the real keychain, so real-device keychain behaviour is validated via the example app, not CI.
- Crypto tests (`KeychainCryptoTests.swift`) cover only the keychain-free parts: flag/error mapping, descriptors, `SecAccessControl` construction, and validation that throws before any `SecItem` call. Biometric prompts and Secure Enclave behaviour need real hardware → example app.

### Constraints to preserve

- Swift 6 language mode with `strictMemorySafety()`; both library targets must stay warning-free under strict concurrency.
- `SwiftStash` module must not import SwiftUI (its whole reason to exist). UI-facing code goes in `SwiftStashUI`.
- The core wrappers `Stash` and `SecureStash` are `Sendable` with `nonmutating set` — keep them usable as `static let`. `Stashed` is a `@MainActor` SwiftUI `DynamicProperty`, not the shared-state wrapper.
- Public API is documented with DocC; update the catalogue when adding public symbols. The package catalogue (articles + core symbols) is `Sources/SwiftStash/SwiftStash.docc/`; `Sources/SwiftStashUI/SwiftStashUI.docc/` holds only that module's landing page (its abstract is the module's tile on the merged documentation site built by `Scripts/build-docs.sh`).
- Logging: keys are `.private`, type names `.public` — never log stored values.

### Branding

All visual material (README graphics, DocC theming, social previews, example-app branding) follows `Branding/BRANDING.md` — the approved brand book, with ready-to-use SVG assets in `Branding/Assets/`. Key locked decisions: the padlock-in-square-brackets logo (canonical SVG geometry, never redrawn), Swift Orange `#F05138` as the sole primary accent, the two-tone wordmark ("Swift" white/dark + "Stash" orange), and real README code on every graphic. Read the brand book before producing or editing any branded asset; do not change those decisions without asking the maintainer.
