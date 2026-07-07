//
//  CustomCodersScreen.swift
//  SwiftStashExample
//
// Copyright (c) 2026 SwiftStash contributors
// SPDX-License-Identifier: MIT
//

import SwiftUI
import SwiftStashUI

/// The same `Codable` model is written under two keys — one with the default coders,
/// one with a configured ISO-8601 pair — so the stored JSON can be compared live.
private let isoEncoder: JSONEncoder = {
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    return encoder
}()

private let isoDecoder: JSONDecoder = {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    return decoder
}()

/// Custom `JSONEncoder`/`JSONDecoder` for `codable:` storage.
///
/// By default the `codable:` initialisers use standard coders. Advanced projects whose
/// persisted format needs non-default strategies (dates, keys) pass their own pair —
/// both sides must match, or previously stored payloads stop decoding and the wrapper
/// falls back to the default value.
struct CustomCodersScreen: View {

    @Stashed(codable: "coderDefaultCheckpoint") private var defaultCheckpoint: SyncCheckpoint = .initial

    @Stashed(codable: "coderIsoCheckpoint", encoder: isoEncoder, decoder: isoDecoder)
    private var isoCheckpoint: SyncCheckpoint = .initial

    // The labelled spelling takes the same coder parameters:
    // @Stashed(codable: "coderIsoCheckpoint", defaultValue: .initial, encoder: isoEncoder, decoder: isoDecoder)

    var body: some View {
        Form {
            Section {
                LabeledContent("Last sync", value: defaultCheckpoint.lastSync.formatted())
                LabeledContent("Stored JSON", value: storedJSON(forKey: "coderDefaultCheckpoint"))
            } header: {
                Text("Default coders")
            } footer: {
                Text("The default JSONEncoder writes dates as seconds since 2001 — compact, but opaque to anything that isn't Foundation.")
            }

            Section {
                LabeledContent("Last sync", value: isoCheckpoint.lastSync.formatted())
                LabeledContent("Stored JSON", value: storedJSON(forKey: "coderIsoCheckpoint"))
            } header: {
                Text("ISO-8601 coders")
            } footer: {
                Text("The same model, ISO-8601 strategy: a timestamp any external system can read. Encoder and decoder must use matching strategies.")
            }

            Section {
                Button("Record sync now") {
                    let checkpoint = SyncCheckpoint(deviceName: deviceName, lastSync: .now)
                    defaultCheckpoint = checkpoint
                    isoCheckpoint = checkpoint
                }
                Button("Reset both keys", role: .destructive) {
                    defaultCheckpoint = .initial
                    isoCheckpoint = .initial
                }
            } footer: {
                Text("Changing the coders on a key with data already stored is a format change — the old payload may no longer decode. Pick the strategies per key, once.")
            }
        }
        .navigationTitle("Custom JSON coders")
        .navigationBarTitleDisplayMode(.inline)
    }

    /// Peek at the raw UserDefaults contents to show the actual stored format.
    private func storedJSON(forKey key: String) -> String {
        guard let data = UserDefaults.standard.data(forKey: key) else { return "nothing stored" }
        return String(data: data, encoding: .utf8) ?? "\(data.count) bytes"
    }

    private var deviceName: String {
        UIDevice.current.name
    }
}

#Preview {
    NavigationStack { CustomCodersScreen() }
}
