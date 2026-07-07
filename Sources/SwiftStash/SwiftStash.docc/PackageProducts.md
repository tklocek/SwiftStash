# Package Products

Choose the smallest SwiftStash product that matches the target's responsibilities.

## SwiftStash

Import `SwiftStash` in view models, services, actors, command-line tools, extensions, and other
non-view code. It contains:

- `@Stash` for type-safe UserDefaults storage.
- `@SecureStash` and `KeychainManager` for Keychain storage.
- `StashHandle` and per-key asynchronous observation.
- Shared UserDefaults, Keychain, and logging configuration.

The module does not import SwiftUI. Its `Stash` and `SecureStash` wrappers are `Sendable`, use
non-mutating setters, and can be held as `static let` values under Swift 6 strict concurrency.

```swift
import SwiftStash

enum AppState {
    static let launchCount = Stash(key: "launchCount", defaultValue: 0)
}

AppState.launchCount.wrappedValue += 1
```

## SwiftStashUI

Import `SwiftStashUI` in SwiftUI views that need a persisted value as a `Binding`. It contains
`@Stashed`, a main-actor-isolated `DynamicProperty` backed by UserDefaults.

```swift
import SwiftStashUI
import SwiftUI

struct SettingsView: View {
    @Stashed("displayName") private var displayName = ""

    var body: some View {
        TextField("Display name", text: $displayName)
    }
}
```

`SwiftStashUI` depends on the core product internally, but it does not re-export the core module.
Import `SwiftStash` as well when the same source file uses `SwiftStash.configure…`, `@Stash`, or
`@SecureStash`.

For initialisers, observation details, and concurrency guidance, see <doc:SwiftUIStorage>.

