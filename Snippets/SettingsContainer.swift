// A Foundation-only settings container backed by @Stash — no SwiftUI required.
// Primitives and enums are stored exactly like @AppStorage stores them;
// Codable types are stored as JSON Data under the codable: label.

import Foundation
import SwiftStash

struct Profile: Codable {
    var displayName = ""
    var favoriteCount = 0
}

enum Theme: String {
    case system, light, dark
}

// Codable storage takes custom coders when the persisted format needs
// non-default strategies — both sides must match.
let isoEncoder: JSONEncoder = {
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    return encoder
}()
let isoDecoder: JSONDecoder = {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    return decoder
}()

struct Checkpoint: Codable {
    var lastSync = Date(timeIntervalSince1970: 0)
}

struct AppSettings {
    @Stash(SettingsKey.username)
    var username = ""
    
    @Stash(SettingsKey.lastLogin)
    var lastLogin: Date?                    // optional: assigning nil removes the key
    
    @Stash(SettingsKey.theme)
    var theme: Theme = .system              // stored as the raw value, like @AppStorage
    
    @Stash(codable: SettingsKey.profile)
    var profile = Profile()                 // stored as JSON Data
    
    @Stash(codable: SettingsKey.checkpoint, encoder: isoEncoder, decoder: isoDecoder)
    var checkpoint = Checkpoint()           // JSON Data with ISO-8601 dates
    
    // Every form also has a labelled equivalent, e.g.
    // @Stash(key: SettingsKey.username, defaultValue: "") var username: String
    
    private enum SettingsKey: String {
        case username, lastLogin, theme, profile, checkpoint
    }
}

var settings = AppSettings()
settings.username = "jappleseed"
settings.theme = .dark

// The projected value distinguishes "never set" from "set to the default"
// and can remove the stored value entirely.
if settings.$lastLogin.exists {
    settings.$lastLogin.remove()
}
