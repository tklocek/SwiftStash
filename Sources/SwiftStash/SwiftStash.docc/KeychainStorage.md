# Keychain Storage with @SecureStash

Store sensitive data securely in the system Keychain on Apple platforms.

## Overview

The `@SecureStash` property wrapper provides type-safe access to the Keychain with automatic encryption, access control, and optional iCloud synchronisation.

All operations use the data protection keychain. This makes accessibility settings effective
on macOS as well, where the host application must be signed with an application identifier;
an unsigned executable receives `errSecMissingEntitlement`.

A service is mandatory. Configure it before creating an instance property wrapper, or pass
`service:` directly to that wrapper. Reads, updates, deletes, `exists`, and `allKeys` match
items regardless of their synchronizable state. Only a new save writes the exact
`isSynchronizable` flag, and wrapper updates re-apply the wrapper's current accessibility.

## Configuration

### Global Configuration (Recommended)

Configure once at app launch:

```swift
import SwiftStash

// In App.init() or AppDelegate
SwiftStash.configureKeychain(
    service: Bundle.main.bundleIdentifier!,
    accessibility: .whenUnlockedThisDeviceOnly
)
SwiftStash.configureLogging(level: .normal)
```

### Per-Wrapper Configuration

Override global settings for specific items:

```swift
@SecureStash(
    key: "biometricKey",
    service: "com.myapp",
    accessibility: .whenPasscodeSetThisDeviceOnly
)
var biometricKey: Data?
```

## Basic Usage

### String Storage

```swift
@SecureStash(key: "authToken")
var authToken: String?

@SecureStash(key: "apiKey")
var apiKey: String?

// Usage
authToken = "secret_token_12345"
print(authToken ?? "No token")
authToken = nil  // Deletes from keychain
```

### Data Storage

```swift
@SecureStash(key: "encryptionKey")
var encryptionKey: Data?

// Usage
encryptionKey = Data(repeating: 0x42, count: 32)
```

### Codable Types

```swift
struct Credentials: Codable {
    let username: String
    let password: String
}

@SecureStash(codable: "userCredentials")
var credentials: Credentials?

// Usage
credentials = Credentials(username: "user", password: "pass")
```

## Keychain Accessibility Levels

Choose security level based on your needs:

### `.whenPasscodeSetThisDeviceOnly` (Most Secure, Default)

```swift
@SecureStash(
    key: "sensitiveData",
    accessibility: .whenPasscodeSetThisDeviceOnly
)
var sensitiveData: Data?
```

- Only accessible when device is unlocked
- Requires passcode to be set
- Never backed up or synced
- **Best for:** Biometric keys, highly sensitive data

### `.whenUnlockedThisDeviceOnly`

```swift
@SecureStash(
    key: "authToken",
    accessibility: .whenUnlockedThisDeviceOnly
)
var authToken: String?
```

- Only accessible when device is unlocked
- Never backed up or synced
- **Best for:** Auth tokens, API keys, passwords

### `.afterFirstUnlockThisDeviceOnly`

```swift
@SecureStash(
    key: "syncToken",
    accessibility: .afterFirstUnlockThisDeviceOnly
)
var syncToken: String?
```

- Accessible after first unlock post-restart
- Never backed up or synced
- **Best for:** Background sync tokens

### `.whenUnlocked`

```swift
@SecureStash(
    key: "cloudPassword",
    accessibility: .whenUnlocked,
    isSynchronizable: true
)
var cloudPassword: String?
```

- Accessible when device is unlocked
- Can be backed up and synced to iCloud
- **Best for:** Data you want on all user devices

### `.afterFirstUnlock`

```swift
@SecureStash(
    key: "pushToken",
    accessibility: .afterFirstUnlock,
    isSynchronizable: true
)
var pushToken: String?
```

- Accessible after first unlock post-restart
- Can be backed up and synced to iCloud
- **Best for:** Background-accessible data that should follow the user to new devices

## Keychain Item Classes

### Generic Password (Default)

For general secrets:

```swift
@SecureStash(key: "apiKey")
var apiKey: String?
```

### Internet Password

For domain-specific credentials:

```swift
@SecureStash(
    key: "password",
    itemClass: .internetPassword(domain: "api.example.com")
)
var apiPassword: String?

// Different domain = different keychain item
@SecureStash(
    key: "password",
    itemClass: .internetPassword(domain: "different.com")
)
var otherPassword: String?
```

## Projected Value: `$property`

`@SecureStash` projects a ``SecureStashHandle`` for the questions the wrapped value alone cannot answer:

```swift
@SecureStash(key: "authToken")
var authToken: String?

$authToken.exists      // presence probe — no read, no decode
$authToken.remove()    // deletes the item; same effect as authToken = nil
$authToken.key         // "authToken"
```

`exists` reports `true` even when the stored payload can no longer be decoded into the
wrapped type (reads then return `nil`) — this distinguishes "no item" from "item with an
unreadable payload". Unlike ``StashHandle``, there is no `updates` stream: the keychain
has no change-notification mechanism to observe.

## Custom Encoders/Decoders

For special encoding requirements:

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

Custom encoders/decoders are specified per-wrapper since encoding needs can vary between types.
Configure them fully before passing them in — the wrapper keeps using the same instances,
so they must not be mutated afterwards.

## Configuration Patterns

### Pattern 1: Fully Manual

```swift
@SecureStash(
    key: "token",
    service: "com.myapp",
    accessibility: .whenUnlockedThisDeviceOnly
)
var token: String?
```

### Pattern 2: Global Defaults

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

### Pattern 3: Global with Overrides

```swift
// Global defaults
SwiftStash.configureKeychain(
    service: "com.myapp",
    accessibility: .whenUnlockedThisDeviceOnly
)

// Most items use defaults
@SecureStash(key: "token")
var token: String?

// Override for specific items
@SecureStash(
    key: "biometricKey",
    accessibility: .whenPasscodeSetThisDeviceOnly
)
var biometricKey: Data?
```

## Best Practices

### Always Use Optionals

```swift
// ✅ Correct
@SecureStash(key: "token")
var token: String?

// ❌ Not supported
@SecureStash(key: "token", defaultValue: "")
var token: String
```

### Choose Appropriate Accessibility

```swift
// ✅ User credentials - highest security
@SecureStash(
    key: "password",
    accessibility: .whenPasscodeSetThisDeviceOnly
)
var password: String?

// ✅ Background token - accessible after unlock
@SecureStash(
    key: "syncToken",
    accessibility: .afterFirstUnlockThisDeviceOnly
)
var syncToken: String?
```

### Clean Up on Logout

```swift
func logout() {
    authToken = nil
    refreshToken = nil
    userCredentials = nil
}
```

### Use Service Identifiers Wisely

```swift
// ✅ App-specific data
SwiftStash.configureKeychain(
    service: Bundle.main.bundleIdentifier!
)

// ✅ Separate namespace for a subsystem in the same target
SwiftStash.configureKeychain(
    service: "com.myapp.authentication"
)
```

## Example: Complete Auth Flow

```swift
import SwiftStash

class AuthManager {
    @SecureStash(key: "authToken")
    private var authToken: String?
    
    @SecureStash(key: "refreshToken")
    private var refreshToken: String?
    
    @SecureStash(codable: "userSession")
    private var userSession: UserSession?
    
    func login(username: String, password: String) async throws {
        let response = try await apiClient.login(username, password)
        
        // Store securely in keychain
        authToken = response.authToken
        refreshToken = response.refreshToken
        userSession = response.session
    }
    
    func logout() {
        // Clear all secure data
        authToken = nil
        refreshToken = nil
        userSession = nil
    }
    
    var isAuthenticated: Bool {
        authToken != nil
    }
}
```

## See Also

- <doc:KeychainConfiguration>
- <doc:KeychainHelpers>
- ``SecureStash``
- ``SecureStashHandle``
- ``SwiftStash/configureKeychain(service:accessibility:isSynchronizable:itemClass:)``
- ``KeychainAccessibility``
