//
//  StashInViewScreen.swift
//  SwiftStashExample
//
// Copyright (c) 2026 SwiftStash contributors
// SPDX-License-Identifier: MIT
//

import SwiftUI
import SwiftStash

/// Plain `@Stash` used directly inside a view — the "load on appear, save on action"
/// pattern.
///
/// `@Stash` is pure Foundation and is *not* a `DynamicProperty`: writing to it does not
/// re-render this view, and external writes do not refresh it. That is the right trade-off
/// for view models and services; inside a view you pair it with local `@State`, or reach
/// for `@Stashed` instead (previous screen).
struct StashInViewScreen: View {

    @Stash(SharedKey.username) private var username = ""

    /// Editable draft; the persisted value is only touched on explicit actions.
    @State private var draft = ""
    @State private var stored = ""

    var body: some View {
        Form {
            Section {
                LabeledContent("Stored value", value: stored.isEmpty ? "—" : stored)
                TextField("Draft username", text: $draft)
                Button("Save") {
                    username = draft
                    stored = username
                }
                Button("Reload from UserDefaults") {
                    stored = username
                    draft = username
                }
            } footer: {
                Text("Nothing persists until Save. This screen writes the same key as the @Stashed screen — flip between the two to see both directions.")
            }
        }
        .navigationTitle("Direct @Stash")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            stored = username
            draft = username
        }
    }
}

#Preview {
    NavigationStack { StashInViewScreen() }
}
