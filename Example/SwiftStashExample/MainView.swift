//
//  MainView.swift
//  SwiftStashExample
//
// Copyright (c) 2026 SwiftStash contributors
// SPDX-License-Identifier: MIT
//

import SwiftUI

/// The scenario map of the whole package. Every public API surface has a screen here,
/// so each feature can be exercised manually on a device or simulator.
struct MainView: View {

    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink("@Stashed in a SwiftUI view") { StashedInViewScreen() }
                    NavigationLink("@Stash directly in a view") { StashInViewScreen() }
                    NavigationLink("ObservableObject view model") { ObservableObjectScreen() }
                    NavigationLink("@Observable view model") { ObservableModelScreen() }
                    NavigationLink("Repository pattern") { RepositoryScreen() }
                    NavigationLink("Static shared state (Swift 6)") { SharedStateScreen() }
                } header: {
                    Text("Adoption patterns")
                } footer: {
                    Text("The same storage, wired into different app architectures. All six screens share the same keys — change a value in one and revisit another.")
                }

                Section {
                    NavigationLink("Primitives & collections") { PrimitivesScreen() }
                    NavigationLink("Optionals & the $handle") { OptionalsHandleScreen() }
                    NavigationLink("Enums & Codable") { EnumsCodableScreen() }
                    NavigationLink("Custom JSON coders") { CustomCodersScreen() }
                } header: {
                    Text("@Stash · UserDefaults")
                }

                Section {
                    NavigationLink("Typed updates: $property.updates") { HandleUpdatesScreen() }
                    NavigationLink("Any key: SwiftStash.updates(forKey:)") { KeyUpdatesScreen() }
                    NavigationLink("@AppStorage interop") { AppStorageInteropScreen() }
                } header: {
                    Text("Observation")
                }

                Section {
                    NavigationLink("@SecureStash basics") { SecureStashBasicsScreen() }
                    NavigationLink("Codable secrets") { SecureCodableScreen() }
                    NavigationLink("Item class & overrides") { InternetPasswordScreen() }
                    NavigationLink("Helpers: allKeys & clearAll") { KeychainHelpersScreen() }
                    NavigationLink("KeychainManager: typed errors") { KeychainManagerScreen() }
                } header: {
                    Text("@SecureStash · Keychain")
                }

                Section {
                    NavigationLink("Biometric-protected item") { BiometricItemScreen() }
                    NavigationLink("Secure Enclave key") { SecureEnclaveScreen() }
                } header: {
                    Text("Biometrics & Secure Enclave")
                } footer: {
                    Text("Fully functional on a real device. The Secure Enclave is not available in the simulator; the screens surface those errors instead of hiding them.")
                }

                Section {
                    NavigationLink("Logging") { LoggingScreen() }
                    NavigationLink("App Groups & iCloud sync") { EntitlementsScreen() }
                    NavigationLink("About SwiftStash") { AboutScreen() }
                } header: {
                    Text("Configuration")
                }
            }
            .navigationTitle("SwiftStash")
        }
    }
}

#Preview {
    MainView()
}
