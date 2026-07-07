//
//  AppStorageInteropScreen.swift
//  SwiftStashExample
//
// Copyright (c) 2026 SwiftStash contributors
// SPDX-License-Identifier: MIT
//

import SwiftUI
import SwiftStashUI

/// `@AppStorage` and `@Stashed` reading and writing the **same key** — live proof of the
/// zero-cost migration story.
///
/// The storage representation is identical, so an existing app can convert one property
/// at a time: values persisted by `@AppStorage` are read as-is, and vice versa. Increment
/// through either wrapper below; both rows update, because `@Stashed` observes the key
/// via KVO and `@AppStorage` does its own store observation.
struct AppStorageInteropScreen: View {

    @AppStorage("interopCounter") private var appStorageValue = 0
    @Stashed("interopCounter") private var stashedValue: Int = 0

    var body: some View {
        Form {
            Section {
                LabeledContent("@AppStorage reads", value: "\(appStorageValue)")
                LabeledContent("@Stashed reads", value: "\(stashedValue)")
            } footer: {
                Text("One key, two wrappers, always in sync.")
            }

            Section {
                Button("Increment via @AppStorage") { appStorageValue += 1 }
                Button("Increment via @Stashed") { stashedValue += 1 }
            } footer: {
                Text("Migration recipe: replace @AppStorage(\"k\") var x: T = d with @Stashed(\"k\") var x: T = d — rename the attribute, persisted values survive unchanged. Enums stored as raw values interoperate the same way.")
            }
        }
        .navigationTitle("@AppStorage interop")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack { AppStorageInteropScreen() }
}
