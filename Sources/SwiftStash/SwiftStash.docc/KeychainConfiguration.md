# Keychain Configuration

Advanced configuration options for @SecureStash.

## Overview

`SwiftStash.configureKeychain(...)` provides global defaults for keychain operations that can be overridden per-wrapper when needed.

## Global Configuration

### Basic Setup

Configure once at app launch:

```swift
import SwiftStash

SwiftStash.configureKeychain(
    service: Bundle.main.bundleIdentifier!,
    accessibility: .whenUnlockedThisDeviceOnly
)
SwiftStash.configureLogging(level: .normal)
```

### All Configuration Options

```swift
SwiftStash.configureKeychain(
    service: "com.myapp",
    accessibility: .whenPasscodeSetThisDeviceOnly,
    isSynchronizable: false,
    itemClass: .genericPassword
)
SwiftStash.configureLogging(level: .normal)
```

## Configuration Parameters

### service

Service identifier for keychain items (required):

```swift
// App-specific
service: Bundle.main.bundleIdentifier!

// Custom namespace within one target's default access group
service: "com.myapp.authentication"
```

`service` is a namespace attribute, not a Keychain access group. Giving two targets the
same service does not grant them access to each other's items. SwiftStash doesn't currently
expose `kSecAttrAccessGroup`; use a lower-level Keychain implementation when explicit
cross-target Keychain sharing is required.

### accessibility

Access control level (defaults to `.whenPasscodeSetThisDeviceOnly`):

```swift
accessibility: .whenPasscodeSetThisDeviceOnly  // Most secure
accessibility: .whenUnlockedThisDeviceOnly     // Secure
accessibility: .afterFirstUnlockThisDeviceOnly // Background tasks
accessibility: .whenUnlocked                    // iCloud sync enabled
accessibility: .afterFirstUnlock                // iCloud sync enabled
```

See <doc:KeychainStorage> for detailed explanations.

### isSynchronizable

Enable iCloud Keychain sync (defaults to `false`):

```swift
isSynchronizable: false  // Device-only (recommended)
isSynchronizable: true   // Sync across user's devices
```

`true` is valid only with `.whenUnlocked` or `.afterFirstUnlock`. Combining synchronisation
with a `*ThisDeviceOnly` accessibility asserts in debug builds and fails when written in release.

### itemClass

Default keychain item class (defaults to `.genericPassword`):

```swift
itemClass: .genericPassword  // General secrets
itemClass: .internetPassword(domain: "api.example.com")  // Web credentials
```

### encoder / decoder

Custom JSON encoders/decoders can be passed per-wrapper:

```swift
let encoder = JSONEncoder()
encoder.dateEncodingStrategy = .iso8601

let decoder = JSONDecoder()
decoder.dateDecodingStrategy = .iso8601

@SecureStash(
    codable: "timestamp",
    encoder: encoder,
    decoder: decoder
)
var timestamp: DateContainer?
```

Configure the coders fully before passing them in — the wrapper keeps using the same
instances, so they must not be mutated afterwards.

## Per-Wrapper Overrides

Override global settings for specific wrappers:

```swift
// Global defaults
SwiftStash.configureKeychain(
    service: "com.myapp",
    accessibility: .whenUnlockedThisDeviceOnly
)

// Most wrappers use global defaults
@SecureStash(key: "authToken")
var authToken: String?

@SecureStash(key: "refreshToken")
var refreshToken: String?

// Override for highly sensitive data
@SecureStash(
    key: "biometricKey",
    accessibility: .whenPasscodeSetThisDeviceOnly  // Override
)
var biometricKey: Data?

// Override for different service
@SecureStash(
    key: "sharedSecret",
    service: "group.com.myapp.shared"  // Override
)
var sharedSecret: String?
```

## Configuration Strategies

### Strategy 1: No Global Configuration

Specify everything per-wrapper:

```swift
@SecureStash(
    key: "token",
    service: "com.myapp",
    accessibility: .whenUnlockedThisDeviceOnly
)
var token: String?
```

**Pros:** Explicit, clear  
**Cons:** Repetitive, verbose

### Strategy 2: Global Configuration Only

Set once, use everywhere:

```swift
// Configure once
SwiftStash.configureKeychain(
    service: "com.myapp",
    accessibility: .whenUnlockedThisDeviceOnly
)

// Use everywhere
@SecureStash(key: "token1")
var token1: String?

@SecureStash(key: "token2")
var token2: String?
```

**Pros:** DRY, concise  
**Cons:** Less explicit per-wrapper

### Strategy 3: Global with Selective Overrides (Recommended)

Global defaults with overrides when needed:

```swift
// Set sensible defaults
SwiftStash.configureKeychain(
    service: Bundle.main.bundleIdentifier!,
    accessibility: .whenUnlockedThisDeviceOnly
)

// Most wrappers use defaults
@SecureStash(key: "authToken")
var authToken: String?

// Override when needed
@SecureStash(
    key: "biometricKey",
    accessibility: .whenPasscodeSetThisDeviceOnly
)
var biometricKey: Data?
```

**Pros:** Best of both worlds  
**Cons:** None

## App Extensions and Keychain Access Groups

Keychain sharing between an app and extension requires entitlements and a shared
`kSecAttrAccessGroup`. A matching `service` alone is insufficient. SwiftStash doesn't expose
the access-group attribute, so this scenario currently requires a lower-level implementation.

## Multi-Environment Setup

Different configurations per environment:

```swift
#if DEBUG
SwiftStash.configureKeychain(service: "com.myapp.debug")
SwiftStash.configureLogging(level: .verbose)
#else
SwiftStash.configureKeychain(service: "com.myapp")
SwiftStash.configureLogging(level: .minimal)
#endif
```

## See Also

- <doc:KeychainStorage>
- ``KeychainAccessibility``
