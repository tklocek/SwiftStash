//
//  SharedStateScreen.swift
//  SwiftStashExample
//
// Copyright (c) 2026 SwiftStash contributors
// SPDX-License-Identifier: MIT
//

import SwiftUI
import SwiftStash

/// Global persisted state under Swift 6 strict concurrency — the scenario `@AppStorage`
/// cannot serve at all (it is a `DynamicProperty`, unusable outside a view).
///
/// `Stash` is `Sendable` with a `nonmutating set`, so it is safe as a `static let`.
/// There are two spellings, and which one compiles depends on the enclosing type:
enum AppCounters {
    /// In a **nonisolated** type, hold the wrapper itself as `static let` and go through
    /// `.wrappedValue`. The attribute spelling (`@Stash … static var`) is a compile error
    /// here — the synthesized backing storage would be nonisolated global mutable state.
    static let saveTaps = Stash(key: "saveTaps", defaultValue: 0)
}

/// In an **actor-isolated** type, the attribute spelling on `static var` works.
@MainActor
enum AppDefaults {
    @Stash(SharedKey.theme) static var theme: Theme = .system
}

struct SharedStateScreen: View {

    @State private var taps = 0
    @State private var theme = Theme.system

    var body: some View {
        Form {
            Section {
                LabeledContent("AppCounters.saveTaps", value: "\(taps)")
                Button("Increment from anywhere") {
                    // Any code in the process can do this — no view context required.
                    AppCounters.saveTaps.wrappedValue += 1
                    taps = AppCounters.saveTaps.wrappedValue
                }
            } header: {
                Text("static let + .wrappedValue")
            } footer: {
                Text("Nonisolated global state: hold the wrapper, read and write through .wrappedValue.")
            }

            Section {
                Picker("AppDefaults.theme", selection: $theme) {
                    ForEach(Theme.allCases, id: \.self) { theme in
                        Text(theme.rawValue).tag(theme)
                    }
                }
                .onChange(of: theme) {
                    AppDefaults.theme = theme
                }
            } header: {
                Text("@Stash static var (@MainActor)")
            } footer: {
                Text("Same key as the theme on the other adoption screens — this is truly shared state.")
            }
        }
        .navigationTitle("Static shared state")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            taps = AppCounters.saveTaps.wrappedValue
            theme = AppDefaults.theme
        }
    }
}

#Preview {
    NavigationStack { SharedStateScreen() }
}
