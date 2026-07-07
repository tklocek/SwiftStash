// A SwiftUI settings form bound directly to persisted values via @Stashed
// (the SwiftStashUI product). @Stashed shares its storage representation with
// @Stash and @AppStorage — the same keys interoperate across all three.

import SwiftStashUI
import SwiftUI

struct SettingsView: View {
    @Stashed(Key.isEnabled) private var isEnabled = false
    
    @Stashed(Key.username) private var username = ""
    
    var body: some View {
        Form {
            Section(header: Text("Preferences")) {
                Toggle("Enabled", isOn: $isEnabled)
                TextField("Username", text: $username)
            }
        }
    }
    
    private enum Key: String {
        case isEnabled, username
    }
}
