// Keys that carry their default: declare each preference once, then read it
// from a model with @Stash and from a view with @Stashed — the two cannot
// disagree on the default, because there is only one of it.

import Foundation
import SwiftStash
import SwiftStashUI
import SwiftUI

enum Theme: String {
    case system, light, dark
}

extension StashKey<Int> {
    static var launchCount: Self { .init("launchCount", default: 0) }
}

extension StashKey<Theme> {
    static var theme: Self { .init("theme", default: .system) }
}

extension StashKey<Date?> {
    static var lastLogin: Self { .init("lastLogin") }   // optional: defaults to nil
}

final class SessionModel {
    @Stash(.launchCount) var launchCount: Int
    @Stash(.lastLogin) var lastLogin: Date?

    func recordLaunch() {
        launchCount += 1
        lastLogin = Date()
    }
}

struct AppearanceView: View {
    @Stashed(.theme) private var theme: Theme
    @Stashed(.launchCount) private var launchCount: Int

    var body: some View {
        Form {
            Picker("Theme", selection: $theme) {
                Text("System").tag(Theme.system)
                Text("Light").tag(Theme.light)
                Text("Dark").tag(Theme.dark)
            }
            Text("Launched \(launchCount) times")
        }
    }
}
