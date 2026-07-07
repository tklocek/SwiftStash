# UserDefaults Storage with @Stash

Store app preferences and state in UserDefaults with type safety.

## Overview

The `@Stash` property wrapper provides type-safe access to UserDefaults with automatic encoding/decoding for Codable types.

## Basic Usage

### Primitive Types

The `@AppStorage`-style spelling — positional key, default as the assignment — is the
recommended one; every form also has a labelled equivalent
(`@Stash(key: "username", defaultValue: "")`) for contexts without an assignment,
such as direct instantiation.

```swift
@Stash("username") var username = ""

@Stash("age") var age = 0

@Stash("isPremium") var isPremium = false

// Usage
username = "alice"
print(username)  // "alice"
```

### Optional Values

```swift
@Stash("lastLogin") var lastLogin: Date?

@Stash("emailAddress") var emailAddress: String?

// Usage
lastLogin = Date()
lastLogin = nil  // Removes from UserDefaults
```

### Codable Types

```swift
struct UserSettings: Codable {
    var theme: String
    var notificationsEnabled: Bool
}

@Stash(codable: "settings")
var settings = UserSettings(theme: "light", notificationsEnabled: true)

// Usage
settings.theme = "dark"
settings.notificationsEnabled = false
```

Values are encoded with a standard `JSONEncoder`/`JSONDecoder`. When the persisted
format needs non-default strategies (dates, keys), pass configured coders — both
must match, or existing payloads stop decoding:

```swift
let encoder = JSONEncoder()
encoder.dateEncodingStrategy = .iso8601
let decoder = JSONDecoder()
decoder.dateDecodingStrategy = .iso8601

@Stash(codable: "lastSync", encoder: encoder, decoder: decoder)
var lastSync = SyncState()
```

Configure the coders fully before passing them in — the wrapper keeps using the same
instances, so they must not be mutated afterwards.

### Enums (RawRepresentable)

Enums with a property-list raw value are stored as their plain raw value —
interoperable with `@AppStorage` on the same key:

```swift
enum Theme: String {
    case light, dark, system
}

@Stash("theme") var theme: Theme = .system
```

### Optional Codable Types

```swift
struct AppState: Codable {
    var selectedTab: Int
    var scrollPosition: Double
}

@Stash(codable: "appState")
var appState: AppState?

// Usage
appState = AppState(selectedTab: 1, scrollPosition: 100.0)
appState = nil  // Removes from UserDefaults
```

## Custom UserDefaults

Use a custom UserDefaults suite:

```swift
let sharedDefaults = UserDefaults(suiteName: "group.com.myapp.shared")!

@Stash("sharedData", userDefaults: sharedDefaults)
var sharedData = ""
```

## Collections

```swift
@Stash("tags") var tags: [String] = []

@Stash("scores") var scores: [String: Int] = [:]

// Usage
tags.append("swift")
scores["level1"] = 100
```

Collection elements must be property-list native (``PropertyListNativeType``).
`URL` and optionals are supported at the top level only — UserDefaults rejects
them inside collections at runtime, so `[URL]` and `[String?]` are compile
errors. Use `@Stash(codable:)` for those:

```swift
@Stash(codable: "bookmarks") var bookmarks: [URL] = []
```

## Best Practices

### Choose Appropriate Storage

- ✅ **Use @Stash for:** Preferences, UI state, non-sensitive data
- ❌ **Don't use @Stash for:** Passwords, tokens, API keys (use @SecureStash)

### Provide Sensible Defaults

```swift
// ✅ Good - meaningful default
@Stash("theme") var theme = "system"

// ❌ Avoid - empty default when a value should always exist
@Stash("theme") var theme = ""
```

### Use Optional for Truly Optional Data

```swift
// ✅ Good - truly optional
@Stash("lastSync") var lastSync: Date?

// ❌ Avoid - using sentinel value
@Stash("lastSync") var lastSync: Date = .distantPast
```

## Typed Keys

Instead of raw strings, any string-backed `RawRepresentable` works as a key,
so one enum can own all your keys:

```swift
enum SettingsKey: String {
    case username, theme, userProfile
}

@Stash(SettingsKey.username) var username = ""
```

## Key Naming Conventions

```swift
// ✅ Good - descriptive, dot-free
@Stash("appSettingsTheme") var theme = "system"

// ⚠️ Works for storage, but cannot be observed - KVO treats dots as key paths
@Stash("app.settings.theme") var dottedTheme = "system"

// ❌ Avoid - too generic
@Stash("data") var data = ""
```

Prefer dot-free keys: values stored under dotted keys read and write normally,
but ``StashHandle/updates`` and `SwiftStash.updates(forKey:)` never fire for them.

## Projected Value and Observation

`@Stash` projects a ``StashHandle`` via `$property`:

```swift
@Stash("launchCount") var launchCount = 0

$launchCount.exists      // distinguishes "stored default" from "nothing stored"
$launchCount.remove()    // deletes the key; reads fall back to the default

// Typed change stream: yields the current value, then every change
for await count in $launchCount.updates {
    print("launchCount is now \(count)")
}
```

Any key can also be observed without a wrapper — the stream fires for writes
from any source (`@Stash`, `@Stashed`, `@AppStorage`, raw `UserDefaults`):

```swift
for await _ in SwiftStash.updates(forKey: "logLevel") {
    syncLogLevel()
}
```

Both streams buffer with `.bufferingNewest(1)` by default: when writes arrive
faster than the consumer iterates, intermediate elements are dropped and the
consumer sees the latest state. To replay every change instead, pass a policy
explicitly:

```swift
for await count in $launchCount.updates(bufferingPolicy: .unbounded) {
    print("launchCount is now \(count)")
}
```

## Thread Safety

`@Stash` is `Sendable` with a `nonmutating` setter, so wrappers can be shared
across concurrency domains and declared as `static let` under Swift 6 strict
concurrency. Individual reads and writes are as thread-safe as `UserDefaults`
itself; compound operations like `+=` are not atomic.

## See Also

- <doc:KeychainStorage>
- <doc:Logging>
- ``Stash``
- ``StashHandle``
