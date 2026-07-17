# Getting Started

@Metadata {
    @PageImage(purpose: card, source: "card-getting-started", alt: "Getting Started")
}

Learn how to integrate SwiftStash into your project and start using type-safe storage.

## Installation

### Swift Package Manager

Add SwiftStash to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/tklocek/SwiftStash.git", from: "0.1.0")
]
```

Or add it through Xcode: File → Add Package Dependencies → Enter repository URL

## Quick Start

### 1. Import SwiftStash

```swift
import SwiftStash
```

### 2. Configure Logging (Optional)

```swift
// In your app initialisation
SwiftStash.logLevel = .normal  // .minimal, .normal, or .verbose
```

### 3. Use Property Wrappers

#### UserDefaults Storage

```swift
@Stash("username") var username = ""

@Stash("loginCount") var loginCount = 0

// Use like normal properties
username = "john_doe"
loginCount += 1
```

#### Keychain Storage

```swift
// Configure once (typically in App.init())
SwiftStash.configureKeychain(
    service: Bundle.main.bundleIdentifier!,
    accessibility: .whenUnlockedThisDeviceOnly
)

// Use secure storage
@SecureStash(key: "authToken")
var authToken: String?

@SecureStash(codable: "credentials")
var credentials: UserCredentials?

// Use like normal properties
authToken = "secret_token_12345"
authToken = nil  // Deletes from keychain
```

The service is mandatory. The explicit accessibility above is a practical default for
consumer apps; the library's more restrictive default, `.whenPasscodeSetThisDeviceOnly`,
is unavailable on devices that do not have a passcode.

## Next Steps

- <doc:UserDefaultsStorage> - Learn about @Stash for preferences
- <doc:KeychainStorage> - Learn about @SecureStash for sensitive data
- <doc:Logging> - Configure logging for debugging
