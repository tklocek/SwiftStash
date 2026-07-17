# Logging

@Metadata {
    @PageImage(purpose: card, source: "card-logging", alt: "Logging")
}

Configure logging to debug and monitor storage operations.

## Overview

SwiftStash provides integrated logging for both UserDefaults (@Stash) and Keychain (@SecureStash) operations using Apple's OSLog system.

## Log Levels

### `.minimal` (Default, Production)

Only logs critical errors:

```swift
SwiftStash.logLevel = .minimal
```

**Logs:**
- Storage errors
- Keychain errors
- Encoding/decoding failures

**Use when:** Running in production

### `.normal` (Debugging)

Logs errors plus operations:

```swift
SwiftStash.logLevel = .normal
```

**Logs:**
- All `.minimal` logs
- GET, SET, DELETE operations
- Save, update, load operations

**Use when:** Debugging issues, testing

### `.verbose` (Development)

Logs everything including details:

```swift
SwiftStash.logLevel = .verbose
```

**Logs:**
- All `.normal` logs
- Encoding/decoding operations
- Data transformation details

**Use when:** Deep debugging, development

## Configuration

### Global Configuration

Set once for both @Stash and @SecureStash:

```swift
import SwiftStash

// In AppDelegate or App initialisation
SwiftStash.logLevel = .normal
```

### Via `configureLogging`

Equivalent alternative:

```swift
SwiftStash.configureLogging(level: .normal)
```

### Environment-Based Configuration

```swift
#if DEBUG
SwiftStash.logLevel = .verbose
#else
SwiftStash.logLevel = .minimal
#endif
```

## Log Categories

Logs are organised into categories in OSLog:

### UserDefaults (@Stash)

- **Storage.Operations** - GET, SET, REMOVE operations
- **Storage.Errors** - UserDefaults errors
- **Storage.Coding** - JSON encoding/decoding

### Keychain (@SecureStash)

- **Keychain.Operations** - SAVE, LOAD, UPDATE, DELETE operations
- **Keychain.Errors** - Keychain errors
- **Keychain.Coding** - JSON encoding/decoding

All categories use the **SwiftStash** subsystem.

## Viewing Logs

### In Xcode Console

Logs appear automatically in Xcode's debug console when running your app.

### In Console.app

1. Open Console.app
2. Select your device
3. Filter by **Subsystem**: `SwiftStash`
4. Further filter by category (e.g., `Keychain.Operations`)

### Example Filters

```
subsystem:SwiftStash category:Storage.Operations
subsystem:SwiftStash category:Keychain.Errors
subsystem:SwiftStash
```

## Privacy

SwiftStash uses privacy-preserving logging:

- **Keys**: Marked as `.private` (redacted in logs)
- **Type names**: Marked as `.public` (visible)
- **Error messages**: Marked as `.public` (visible)
- **Operations**: Marked as `.public` (visible)

Example log output:

```
[SwiftStash:Storage.Operations] SET [key: <private>, type: String]
[SwiftStash:Keychain.Operations] SAVE [key: <private>, type: Data, class: genericPassword]
[SwiftStash:Storage.Errors] Encoding failed: ... [key: <private>, type: User]
```

## Example Usage

```swift
import SwiftStash

class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        // Configure logging
        #if DEBUG
        SwiftStash.logLevel = .verbose
        #else
        SwiftStash.logLevel = .minimal
        #endif
        
        return true
    }
}

// Now all @Stash and @SecureStash operations will be logged
@Stash("username") var username = ""

@SecureStash(key: "authToken")
var authToken: String?

username = "alice"  // Logged to Storage.Operations
authToken = "secret"  // Logged to Keychain.Operations
```

## Log Level Comparison

| Level | Errors | Operations | Encoding/Decoding | Use Case |
|-------|--------|------------|-------------------|----------|
| `.minimal` | ✅ | ❌ | ❌ | Production |
| `.normal` | ✅ | ✅ | ❌ | Debugging |
| `.verbose` | ✅ | ✅ | ✅ | Development |

## Performance

Logging overhead is minimal:

- Uses Apple's optimized OSLog
- Messages below the configured level are skipped at runtime with negligible cost
- No string interpolation until log is actually emitted
- Safe for production use

## See Also

- ``SwiftStash/logLevel``
- ``StashLogLevel``
- <doc:GettingStarted>
