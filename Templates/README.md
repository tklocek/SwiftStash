# SwiftStash Xcode File Templates

These optional templates create a small, compile-ready starting point for the most common SwiftStash integrations:

- **SwiftStash Settings** — a Foundation-only settings container backed by `@Stash`.
- **SwiftStash Credentials Store** — a Keychain-backed token store using `@SecureStash` with an explicit service and consumer-friendly accessibility.
- **SwiftStash Settings View** — a SwiftUI `Form` whose control is bound directly to `@Stashed`.

They save repetitive setup while keeping the generated code ordinary Swift that you own and can freely change. The sample property and key in each generated file are intended to be renamed and expanded.

## Install

From the repository root, run:

```bash
./Templates/install.sh
```

The script installs the templates for the current macOS user in:

```text
~/Library/Developer/Xcode/Templates/File Templates/SwiftStash/
```

Restart Xcode, then choose **File > New > File** and select a template from the **SwiftStash** section.

Installation is deliberately separate from Swift Package Manager. Adding SwiftStash as a package dependency cannot and does not write files into your home directory.

Re-run `install.sh` after updating the repository to replace the installed SwiftStash templates with their latest versions.

## Compile check (contributors)

Template sources contain Xcode placeholders and are never built by `swift build`, so an API change can break them without any test noticing. CI runs `./Templates/check.sh`, which substitutes the placeholders and compiles every template against the local package in Swift 6 language mode. Run it locally after changing a template or the public API:

```bash
./Templates/check.sh
```

## Uninstall

```bash
./Templates/uninstall.sh
```

The uninstaller removes only the three templates managed by this repository. It leaves unrelated custom Xcode templates untouched.
