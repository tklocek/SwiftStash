# SwiftUI Storage with @Stashed

@Metadata {
    @PageImage(purpose: card, source: "card-swiftui", alt: "SwiftUI Storage")
}

Persist a value and keep a SwiftUI view synchronised with changes to its UserDefaults key.

## Choose an Initialiser

The initialiser follows the same type rules as `@Stash`:

| Value | Initialiser |
| --- | --- |
| Property-list primitive | `@Stashed(key:defaultValue:)` |
| Raw-representable enum with a property-list raw value | `@Stashed(key:defaultValue:)` |
| Other `Codable` value | `@Stashed(codable:defaultValue:)` |
| Optional supported value | The matching initialiser without `defaultValue` |

Every form also has the `@AppStorage`-style spelling — positional key, default as
the assignment (`@Stashed("theme") var theme: Theme = .system`) — which is the
recommended one; the labelled `key:defaultValue:` form is its exact equivalent.
The `codable:` initialisers accept an optional `encoder:`/`decoder:` pair for
non-default JSON strategies, exactly like `@Stash(codable:)` — see
<doc:UserDefaultsStorage> for the details.

All initialisers also accept a `RawRepresentable<String>` key.

## Choose the Store

An explicit UserDefaults instance uses the `store:` label, mirroring `@AppStorage`:

```swift
@Stashed("theme", store: sharedDefaults) var theme: Theme = .system
```

Without it, a hosted `@Stashed` takes its store from the SwiftUI environment, the way
`@AppStorage` honours `.defaultAppStorage(_:)`. Set it with `.stashStore(_:)` — typically next
to `.defaultAppStorage(_:)`, so a test or preview keeps the whole hierarchy on its own suite
and never reads or writes the app's real preferences:

```swift
SettingsView()
    .defaultAppStorage(testDefaults)
    .stashStore(testDefaults)
```

The store resolves in this order:

1. an explicit `store:` argument;
2. the environment: `.stashStore(_:for:)` for the key's ``StashScope``, then `.stashStore(_:)`,
   which covers every wrapper below it, scoped ones included;
3. the store configured for the key's scope, `SwiftStash.configureUserDefaults(_:for:)`;
4. the application-level store, `SwiftStash.configureUserDefaults(_:)`, else `.standard`.

The modifier nearest the view wins: `.stashStore(_:)` replaces any stores set further up,
scoped ones included, while `.stashStore(_:for:)` redirects only its scope. When the
environment's store changes, the wrapper switches to the new store before the next render.

Steps 3 and 4 are read when the wrapper is created. A `@Stashed` used outside a view
hierarchy — read directly from a view struct, as in unit tests — has no environment and uses
them. The environment never reaches `@Stash`, which has no view: a view model's `@Stash` keeps
the store it resolved, so inject the store there explicitly (`userDefaults:`).

## Bind Controls

The projected value is a `Binding<Value>`:

```swift
@Stashed("notificationsEnabled") var notificationsEnabled = true

Toggle("Notifications", isOn: $notificationsEnabled)
```

## Observe External Writes

`@Stashed` observes its individual key, including writes made through `@Stash`, `@AppStorage`,
or raw `UserDefaults`. Keys containing a dot cannot be observed because KVO interprets them
as key paths; storage still works, but the view will not receive those updates.

Observation is briefly debounced to coalesce rapid changes. Instances share an observer for the
same UserDefaults object, key, and value type. The first live wrapper supplies the fallback default
for that shared observer, so wrappers sharing a key must use the same default value.

## Concurrency and Ownership

`@Stashed` is isolated to the main actor because it participates in SwiftUI's view-update
lifecycle. It is not intended for shared non-UI state. Use a `static let Stash(...)` or
`static let SecureStash(...)` when state must cross concurrency domains.

## Module Boundary

The unified documentation catalogue belongs to the core `SwiftStash` module, so `@Stashed` is
documented here as the public API of the separate `SwiftStashUI` product. Add `SwiftStashUI` to
the consuming target and import it before using the wrapper.

