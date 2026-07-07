//___FILEHEADER___

import Foundation
import SwiftStash

struct ___FILEBASENAMEASIDENTIFIER___ {
    private static let service = Bundle.main.bundleIdentifier!

    @SecureStash(
        key: Key.authToken,
        service: Self.service,
        accessibility: .whenUnlockedThisDeviceOnly
    )
    var authToken: String?

    private enum Key: String {
        case authToken
    }
}
