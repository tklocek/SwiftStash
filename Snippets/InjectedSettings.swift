// A settings class that states its store once: tests construct it with their
// own suite, and every @Stash property follows — no store passed per property.

import Foundation
import SwiftStash

extension StashKey<Int> {
    static var launchCount: Self { .init("launchCount", default: 0) }
}

extension StashKey<Bool> {
    static var notificationsEnabled: Self { .init("notificationsEnabled", default: true) }
}

@MainActor
final class AppSettings: StashContainer {
    let stashStore: StashStore

    @Stash(.launchCount) var launchCount: Int
    @Stash(.notificationsEnabled) var notificationsEnabled: Bool

    init(defaults: UserDefaults = .standard) {
        stashStore = StashStore(defaults)
    }
}

// In a test: an isolated suite, never the app's real preferences.
@MainActor
func exampleTest() {
    let suite = UserDefaults(suiteName: "example.tests")!
    let settings = AppSettings(defaults: suite)

    settings.launchCount += 1
    if settings.$launchCount.exists {
        settings.$launchCount.remove()
    }
}
