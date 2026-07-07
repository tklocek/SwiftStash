# Contributing to SwiftStash

Thanks for helping! Issues and pull requests are welcome. This file covers the
practical bits; `AGENTS.md` is the full operational reference (layout, API
decision tables, pitfalls) for both humans and AI coding agents — read it before
making non-trivial changes.

## Getting started

```bash
git clone https://github.com/tklocek/SwiftStash.git
cd SwiftStash
swift build
swift test
```

The example app doubles as the compile check for `SwiftStashUI` consumers —
build it after touching `SwiftStashUI` or doing repo-wide renames (no dev team
is configured, so signing must be disabled):

```bash
cd Example && xcodebuild -project SwiftStashExample.xcodeproj \
  -scheme SwiftStashExample -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO CODE_SIGN_IDENTITY="" build
```

## Ground rules

- **Swift 6 language mode with `strictMemorySafety()`** — both library targets
  must stay warning-free. Mark genuinely unavoidable unsafe constructs with the
  `unsafe` keyword and justify `@unchecked Sendable` with a comment at the site.
- **`SwiftStash` must not import SwiftUI.** UI-facing code goes in `SwiftStashUI`.
- **The core wrappers `Stash` and `SecureStash` stay `Sendable` with
  `nonmutating set`** — usable as `static let`. `Stashed` remains a `@MainActor`
  SwiftUI `DynamicProperty`.
- **Never log stored values.** Keys are `.private`, type names `.public`.
- **Storage representation is `@AppStorage`-compatible** — changing how a value
  type is persisted is a breaking change for existing users' data; don't.
- **Public API needs DocC** — update `Sources/SwiftStash/SwiftStash.docc/` when
  adding public symbols.

## Tests

- Framework is **Swift Testing** (`@Test`, `#expect`), not XCTest. Test names use
  backticks: ``func `Optional String returns nil when key is absent`() ``.
- UserDefaults tests: use `makeUserDefaults(suiteName:)` from
  `Tests/SwiftStashTests/Models/TestHelpers.swift` for per-test isolation.
- Keychain tests: wrap in `runWithMockBackend { … }` — tests must never touch the
  real keychain.
- New behavior needs a test; bug fixes need a regression test.

## Pull requests

- Keep PRs focused — one logical change per PR.
- `swift test` must pass and the example app must build.
- Describe *why*, not just *what*, in the PR body.

## Security issues

Please don't open public issues for vulnerabilities — see [SECURITY.md](SECURITY.md).
