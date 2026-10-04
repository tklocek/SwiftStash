// An @Observable view model whose persisted properties are declared once:
// no observable mirror, no restore at launch, and a write from anywhere —
// a @Stashed in a settings view, another process — updates the views
// observing the model.

import Foundation
import Observation
import SwiftStash

extension StashKey<Int> {
    static var timerMinutes: Self { .init("timerMinutes", default: 25) }
}

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
@MainActor @Observable
final class TimerViewModel: StashObservable {
    @ObservationIgnored @Stash(.timerMinutes) var minutes: Int
    var isRunning = false

    func start() {
        isRunning = true
    }
}
