# Security Policy

## Reporting a Vulnerability

If you find a security issue in SwiftStash — anything from an incorrect keychain
query that weakens item protection to a path that could leak stored values into
logs — please **do not open a public issue**.

Instead, either:

- use GitHub's private vulnerability reporting ("Report a vulnerability" under the
  repository's **Security** tab), or
- email **swiftstash.security@icloud.com** with a description and, if possible, a minimal
  reproduction.

You can expect an acknowledgement within a few days. Please give us a reasonable
window to ship a fix before disclosing publicly.

## Scope: what SwiftStash does and does not protect

So that reports (and expectations) are calibrated, this is the threat model:

**`@Stash` / `@Stashed` (UserDefaults)**

- Values are stored in **plain text** in the app's preferences plist. UserDefaults
  is the right place for preferences and UI state, never for secrets. SwiftStash
  never logs stored values (keys are logged as `.private`, only type names are
  `.public`), but the store itself is not encrypted.

**`@SecureStash` / `KeychainManager` (Keychain)**

- Items are stored in the system keychain (the data protection keychain on all
  platforms, including macOS), encrypted at rest by the OS and gated by the
  configured `KeychainAccessibility`.
- This protects against: reading the value from device backups (with
  `*ThisDeviceOnly` levels), access while the device is locked (with
  `whenUnlocked*` levels), and other apps reading your items.
- This does **not** protect against: a compromised (jailbroken/rooted) device, a
  malicious process running with your app's entitlements, or memory inspection —
  decrypted values live in process memory as ordinary `String`/`Data` instances
  while in use.

## Supported Versions

Security fixes land on `main` and are included in the next release. Until 1.0,
we do not backport fixes to earlier tags — please stay on the latest release.
