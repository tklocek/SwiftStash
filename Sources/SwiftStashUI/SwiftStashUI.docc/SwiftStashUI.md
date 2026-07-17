# ``SwiftStashUI``

@Metadata {
    @PageImage(purpose: icon, source: "technology-icon-ui", alt: "The SwiftStash logo: a padlock between square brackets")
}

SwiftUI bindings for SwiftStash — the `@Stashed` dynamic property keeps views synchronised with UserDefaults.

## Overview

![The SwiftStash lockup: a padlock between square brackets, followed by the SwiftStash wordmark](swiftstash-lockup)

`SwiftStashUI` is the SwiftUI-facing product of the SwiftStash package. Its single
public symbol, ``Stashed``, is a `DynamicProperty` that persists a value in
UserDefaults using the same storage representation as `@Stash` and `@AppStorage`,
re-renders the view when the key changes from any writer, and projects a
`Binding<Value>` for SwiftUI controls:

```swift
import SwiftStashUI

struct SettingsView: View {
    @Stashed("notificationsEnabled") var notificationsEnabled = true

    var body: some View {
        Toggle("Notifications", isOn: $notificationsEnabled)
    }
}
```

The initialisers follow the same type rules as `@Stash`: property-list primitives
and raw-representable enums use the positional or `key:defaultValue:` forms, any
other `Codable` value uses `codable:`, and optionals omit the default. An explicit
UserDefaults instance is passed via `store:`, mirroring `@AppStorage`.

The full usage guide — initialiser table, binding patterns, observation
behaviour, and concurrency notes — lives in the SwiftUI Storage article of the
core `SwiftStash` module's documentation, alongside the rest of the package
catalogue.

## Topics

### Property Wrappers

- ``Stashed``
