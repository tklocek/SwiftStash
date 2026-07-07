//___FILEHEADER___

import SwiftStash

struct ___FILEBASENAMEASIDENTIFIER___ {
    @Stash(key: Key.isEnabled, defaultValue: false)
    var isEnabled: Bool

    private enum Key: String {
        case isEnabled
    }
}
