//___FILEHEADER___

import SwiftStashUI
import SwiftUI

struct ___FILEBASENAMEASIDENTIFIER___: View {
    @Stashed(key: Key.isEnabled, defaultValue: false)
    private var isEnabled: Bool

    var body: some View {
        Form {
            Section("Preferences") {
                Toggle("Enabled", isOn: $isEnabled)
            }
        }
    }

    private enum Key: String {
        case isEnabled
    }
}
