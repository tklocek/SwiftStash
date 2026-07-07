//
//  HandleUpdatesScreen.swift
//  SwiftStashExample
//
// Copyright (c) 2026 SwiftStash contributors
// SPDX-License-Identifier: MIT
//

import SwiftUI
import SwiftStash

/// Typed per-key observation: `$property.updates` is an `AsyncStream<Value>` that yields
/// the **current value immediately**, then the fresh value after every change — no matter
/// who wrote it (`@Stash`, `@Stashed`, `@AppStorage`, raw `UserDefaults.set`).
///
/// The two streams below observe the same key with different buffering policies:
/// - default `.bufferingNewest(1)` — bursts coalesce, a slow consumer sees only the
///   latest state (right for state sync),
/// - `.unbounded` — every intermediate value is delivered.
///
/// Tap "Burst +10" and compare the two logs.
struct HandleUpdatesScreen: View {

    @Stash("observedCounter") private var counter = 0

    @State private var coalesced: [Int] = []
    @State private var unbounded: [Int] = []

    var body: some View {
        Form {
            Section {
                Button("Increment") { counter += 1 }
                Button("Burst +10") {
                    for _ in 0..<10 { counter += 1 }
                }
                Button("Reset key", role: .destructive) {
                    $counter.remove()
                    coalesced = []
                    unbounded = []
                }
            } footer: {
                Text("Writes go through the plain @Stash wrapper; the UI below only changes because the streams fire.")
            }

            Section("Received · .bufferingNewest(1) — default") {
                Text(log(coalesced))
            }

            Section {
                Text(log(unbounded))
            } header: {
                Text("Received · .unbounded")
            } footer: {
                Text("After a burst, the default policy typically skips intermediate values while .unbounded replays all of them. Both yield the current value first.")
            }
        }
        .navigationTitle("$property.updates")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            for await value in $counter.updates {
                coalesced.append(value)
                // Slow consumer: give bursts time to pile up so coalescing is visible.
                try? await Task.sleep(for: .milliseconds(100))
            }
        }
        .task {
            for await value in $counter.updates(bufferingPolicy: .unbounded) {
                unbounded.append(value)
                try? await Task.sleep(for: .milliseconds(100))
            }
        }
    }

    private func log(_ values: [Int]) -> String {
        values.isEmpty ? "—" : values.map(String.init).joined(separator: ", ")
    }
}

#Preview {
    NavigationStack { HandleUpdatesScreen() }
}
