# Keychain Helpers

Utility methods for managing keychain items.

## Overview

`SecureStashHelpers` provides static methods for common keychain operations like batch operations and existence checks.

## Existence Checks

Check if a keychain item exists:

```swift
if SecureStashHelpers.exists(
    key: "authToken",
    service: "com.myapp"
) {
    print("Token exists")
} else {
    print("No token found")
}
```

Use case: Check authentication state without loading the actual value.

## Batch Operations

### List All Keys

Retrieve all keys for a service:

```swift
let keys = SecureStashHelpers.allKeys(
    service: "com.myapp"
)
print("Stored keys: \(keys)")
// ["authToken", "refreshToken", "userId", ...]
```

Parameters:
- `service`: Service identifier
- `itemClass`: Item class (default: `.genericPassword`)

**Note:** Only works with `.genericPassword` and `.internetPassword` classes.

### Clear All Items

**Use with caution!** Deletes all items for a service:

```swift
let deletedCount = SecureStashHelpers.clearAll(
    service: "com.myapp"
)
print("Deleted \(deletedCount) items")
```

The number of deleted items is returned directly — the call is synchronous,
and the result can be ignored when it isn't needed.

Use case: Complete logout or app reset.

### Clear All Example

```swift
class AuthManager {
    func completeLogout() {
        // Clear all keychain data
        let count = SecureStashHelpers.clearAll(
            service: Bundle.main.bundleIdentifier!
        )
        print("Cleared \(count) keychain items")
        
        // Clear UserDefaults
        if let bundleID = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleID)
        }
    }
}
```

## Complete Example

```swift
import SwiftStash

class DataManager {
    private let service = Bundle.main.bundleIdentifier!
    
    // Check if user is logged in
    var isLoggedIn: Bool {
        SecureStashHelpers.exists(key: "authToken", service: service)
    }
    
    // List all stored credentials
    func listStoredData() -> [String] {
        SecureStashHelpers.allKeys(service: service)
    }
    
    // Complete app reset
    func resetAllData() {
        let count = SecureStashHelpers.clearAll(service: service)
        print("Cleared \(count) keychain items")
    }
}
```

## Best Practices

### Existence Checks

- ✅ Use for quick authentication state checks
- ✅ More efficient than loading and checking for nil
- ❌ Don't use if you need the actual value

### Batch Operations

- ✅ Use `allKeys()` for debugging/admin features
- ✅ Use `clearAll()` for logout/reset
- ⚠️ Be cautious with `clearAll()` - it's irreversible

## See Also

- ``SecureStashHelpers``
- <doc:KeychainStorage>
- <doc:KeychainConfiguration>
