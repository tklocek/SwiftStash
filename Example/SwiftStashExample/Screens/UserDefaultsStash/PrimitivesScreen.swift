//
//  PrimitivesScreen.swift
//  SwiftStashExample
//
// Copyright (c) 2026 SwiftStash contributors
// SPDX-License-Identifier: MIT
//

import SwiftUI
import SwiftStashUI

/// Every property-list primitive the `key:` initialiser accepts, on one screen:
/// `String`, `Int`, `Double`, `Bool`, `Date`, `URL`, `Data`, plus arrays and
/// string-keyed dictionaries of those.
///
/// Misusing the primitive initialiser with any other type is a **compile error**
/// (the `UserDefaultsPrimitiveType` marker protocol), not a runtime crash — try:
///
/// ```swift
/// @Stashed("profile") var p: UserProfile = .empty
/// // error — UserProfile is not a plist type; use the codable: label instead
/// ```
///
/// Collections are checked one level deeper: `URL` and optionals are storable at the
/// top level only, so `[URL]` or `[String?]` also fail to compile (UserDefaults would
/// reject them at runtime). Use `codable:` for those shapes.
struct PrimitivesScreen: View {

    @Stashed("primitiveString") private var text = ""
    @Stashed("primitiveInt") private var count = 0
    @Stashed("primitiveDouble") private var ratio = 0.5
    @Stashed("primitiveBool") private var flag = false
    @Stashed("primitiveDate") private var lastSaved: Date?
    @Stashed("primitiveURL") private var website: URL?
    @Stashed("primitiveStringArray") private var tags: [String] = []
    @Stashed("primitiveDictionary") private var scores: [String: Int] = [:]

    @State private var newTag = ""

    var body: some View {
        Form {
            Section("Scalars") {
                TextField("String", text: $text)
                Stepper("Int: \(count)", value: $count)
                LabeledContent("Double") {
                    Slider(value: $ratio, in: 0...1)
                }
                Toggle("Bool", isOn: $flag)
            }

            Section {
                LabeledContent("Date?", value: lastSaved?.formatted(date: .abbreviated, time: .shortened) ?? "nil")
                Button("Set to now") { lastSaved = .now }
                LabeledContent("URL?", value: website?.absoluteString ?? "nil")
                Button("Set example URL") { website = URL(string: "https://example.com") }
            } header: {
                Text("Top-level-only types")
            } footer: {
                Text("Date and URL are storable on their own, but not inside collections — [URL] is a compile error; store it with the codable: label.")
            }

            Section {
                ForEach(tags, id: \.self) { tag in
                    Text(tag)
                }
                HStack {
                    TextField("New tag", text: $newTag)
                    Button("Add") {
                        tags.append(newTag)
                        newTag = ""
                    }
                    .disabled(newTag.isEmpty)
                }
                LabeledContent("[String: Int]", value: scores.isEmpty ? "empty" : scores.map { "\($0.key)=\($0.value)" }.sorted().joined(separator: ", "))
                Button("Bump score") { scores["taps", default: 0] += 1 }
            } header: {
                Text("Collections")
            }
        }
        .navigationTitle("Primitives")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack { PrimitivesScreen() }
}
