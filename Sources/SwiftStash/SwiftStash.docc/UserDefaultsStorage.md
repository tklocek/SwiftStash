# UserDefaults Storage with @Stash

@Metadata {
    @PageImage(purpose: card, source: "card-userdefaults", alt: "UserDefaults Storage")
}

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

## Choosing the Store

Every wrapper resolves its store once, when it is created, in this order:

1. an explicit `userDefaults:` argument;
2. the store configured for the key's ``StashScope``, when the key's type is a
   ``StashScopedKey``;
3. the application-level store, else `UserDefaults.standard`.

A `@Stash` property of a ``StashContainer`` class uses the container's store between steps 1
and 2 — see <doc:UserDefaultsStorage#A-Store-per-Instance>. `@Stashed`
adds the SwiftUI environment at the same place — see <doc:SwiftUIStorage>.
`SwiftStash.updates(forKey:in:bufferingPolicy:)` follows the same order, with `in:` as the
explicit store.

### An Explicit Store

Pass the instance for one wrapper; nothing else changes:

```swift
let sharedDefaults = UserDefaults(suiteName: "group.com.myapp.shared")!

@Stash("sharedData", userDefaults: sharedDefaults)
var sharedData = ""
```

### The Application-Level Store

Configure it once at launch, before any wrapper is created — wrappers that already exist
keep the store they resolved:

```swift
SwiftStash.configureUserDefaults(suiteName: "group.com.myapp.shared")
// or, with an instance the app already holds:
SwiftStash.configureUserDefaults(sharedDefaults)
```

``SwiftStash/userDefaults`` returns the configured store, for APIs that take a `UserDefaults`,
and ``SwiftStash/resetUserDefaults()`` returns to `.standard`.

### A Store per Instance

A settings type that tests construct with their own suite would otherwise pass the store to
every property. Conform the class to ``StashContainer`` instead: it holds the store once, and
every `@Stash` property declared in it — and its projected value — reads and writes that store:

```swift
@MainActor
final class AppSettings: StashContainer {
    let stashStore: StashStore

    @Stash(.launchCount) var launchCount: Int
    @Stash(.theme) var theme: Theme

    init(defaults: UserDefaults = .standard) {
        stashStore = StashStore(defaults)
    }
}

let settings = AppSettings(defaults: testDefaults)    // every property on the test's suite
```

``StashStore`` wraps the `UserDefaults` so that a main-actor class can satisfy the requirement
with a plain `let`. The container's store wins over scopes and the application level; a
property declared with an explicit `userDefaults:` keeps that store. The store is looked up on
each access, so replacing ``StashContainer/stashStore`` moves every property.

Only classes can be containers — the wrapper reaches the store through its enclosing instance,
which Swift provides for class properties. A `@Stash` in a struct, or in a class that does not
conform, keeps the store it resolved at initialisation.

> Important: The conformance is what routes the properties. Without `: StashContainer`, the
> `stashStore` property is just a property, and the wrappers use the configured store.

### Observable Models

The `@Observable` macro rejects property wrappers on the properties it tracks. Conform an
`@Observable` class to ``StashObservable`` and mark each stash `@ObservationIgnored`; the
wrapper then reports reads and writes to the class's observation registrar itself, so SwiftUI
views observing the model update as for any other property (iOS 17, macOS 14 and later):

```swift
@MainActor @Observable
final class TimerViewModel: StashObservable {
    @ObservationIgnored @Stash(.timerMinutes) var minutes: Int
    var isRunning = false
}
```

There is no observable mirror to keep in sync and no restore step at launch: the value is read
from the store on every access. Writes that bypass the model — a `@Stashed` in a settings
view, another wrapper on the same key, another process — reach its observers as well, on the
thread that wrote. The macro supplies the protocol's requirements, but generates them
`internal`, so a `public` class cannot conform. Add ``StashContainer`` to hold the store in the
model too.

### A Store per Package

A package that uses SwiftStash internally keeps its preferences in a ``StashScope`` of its own,
declared once on its key type:

```swift
extension StashScope {
    static let tipJar = StashScope("TipJarKit")
}

enum TipJarKey: String, StashScopedKey {
    case tipCount, lastTipDate
    static var stashScope: StashScope { .tipJar }
}

@Stash(TipJarKey.tipCount) var tipCount = 0
```

Until somebody configures the scope, its wrappers use the application-level store, so
adopting a scope changes nothing. Configuring it moves every wrapper of the scope that does
not pass an explicit store — the package's own, or the app's, for example into an App Group:

```swift
SwiftStash.configureUserDefaults(groupDefaults, for: .tipJar)
```

> Important: A package configures only its own scope, never the application level.
> ``SwiftStash/configureUserDefaults(_:)`` belongs to the app; a package that called it would
> move the app's preferences too.

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

A key type that also conforms to ``StashScopedKey`` routes its wrappers to its scope's store
(see <doc:UserDefaultsStorage#A-Store-per-Package>).

### Keys That Carry Their Default

A preference read by a model and shown in a view states its default twice with plain keys,
and nothing checks that the two agree. A ``StashKey`` carries the value type and the default,
so every wrapper declared with it reads the same one. Declare each key in an extension of its
value type, so Swift infers the type from the name:

```swift
extension StashKey<Int> {
    static var launchCount: Self { .init("launchCount", default: 0) }
}

extension StashKey<Theme> {
    static var theme: Self { .init(SettingsKey.theme, default: .system) }
}

extension StashKey<Date?> {
    static var lastLogin: Self { .init("lastLogin") }     // optional: defaults to nil
}

@Stash(.launchCount) var launchCount: Int
@Stash(.theme) var theme: Theme
@Stash(codable: .profile) var profile: Profile           // the wrapper still picks the format
```

The declaration names the key and never writes a value; a default assigned at the declaration
does not compile. The wrapper still chooses the storage format: the unlabelled initialiser for
property-list primitives and raw-representable enums, `codable:` for other `Codable` values.
A key built from a ``StashScopedKey`` type carries its scope.

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
