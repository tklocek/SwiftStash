// A Keychain-backed credentials store using @SecureStash.
// Values are always optional: assigning nil deletes the Keychain item.
// The explicit accessibility is the practical choice for consumer apps —
// the library default (.whenPasscodeSetThisDeviceOnly) is unreadable on
// devices without a passcode.

import Foundation
import SwiftStash

struct Credentials: Codable {
    var username: String
    var refreshToken: String
}

struct CredentialsStore {
    private static let service = "com.example.snippets"
    
    @SecureStash(
        key: Key.authToken,
        service: Self.service,
        accessibility: .whenUnlockedThisDeviceOnly
    )
    var authToken: String?
    
    @SecureStash(
        codable: Key.credentials,
        service: Self.service,
        accessibility: .whenUnlockedThisDeviceOnly
    )
    var credentials: Credentials?           // any Codable, JSON-encoded
    
    private enum Key: String {
        case authToken, credentials
    }
}

// Alternatively, configure the service once at app launch and omit it per wrapper:
SwiftStash.configureKeychain(
    service: "com.example.snippets",
    accessibility: .whenUnlockedThisDeviceOnly
)

var store = CredentialsStore()
store.authToken = "secret-token"

// The projected value answers what the wrapped value cannot:
_ = store.$authToken.exists                 // presence probe — no read, no decode
store.$authToken.remove()                   // deletes the item; same as = nil
