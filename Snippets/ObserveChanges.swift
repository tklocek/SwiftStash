// Observing value changes with AsyncStream — updates fire for writes from
// any source: @Stash, @Stashed, @AppStorage, or raw UserDefaults.

import Foundation
import SwiftStash

struct Counter {
    @Stash(key: "launchCount", defaultValue: 0)
    var launchCount: Int
}

let counter = Counter()

// Typed stream via the projected value: yields the current value immediately,
// then every change.
Task {
    for await count in counter.$launchCount.updates {
        print("launchCount is now \(count)")
    }
}

// Untyped stream for any key, no wrapper needed: yields only on change —
// read the current value once before the loop when syncing state.
Task {
    for await _ in SwiftStash.updates(forKey: "launchCount") {
        print("launchCount changed")
    }
}

counter.launchCount += 1
