//
//  StashedTests.swift
//  SwiftStash
//
// Copyright (c) 2026 SwiftStash contributors
// SPDX-License-Identifier: MIT
//

import Foundation
import Testing
import SwiftUI
@testable import SwiftStashUI

/// Comprehensive tests for @Stashed property wrapper.
///
/// Tests cover:
/// - Primitive types (String, Int, Bool, Double, Date)
/// - Codable types
/// - RawRepresentable types (enums)
/// - Optional values for all types
/// - SwiftUI integration (Binding)
/// - Persistence across instances
/// - Error handling
/// - Memory management
/// - Thread safety
///
/// NOTE: @Stashed uses @ObservedObject internally and is designed for SwiftUI Views.
/// These tests access the wrapper outside a rendered View to verify its storage mechanisms.
/// For real-world usage examples, see the Example app's IndividualTestViews.swift.
@MainActor
struct StashedTests {
    
    // MARK: - Primitive Types - Non-Optional
    
    @Test
    func `Non-optional String returns default value when not set`() {
        let (sut, cleanup) = makeStashedTestView()
        defer { cleanup() }
        
        #expect(sut.stringValue == "default")
    }
    
    @Test
    func `Non-optional String can be set and retrieved`() {
        let (sut, cleanup) = makeStashedTestView()
        defer { cleanup() }
        
        sut.stringValue = "Hello Stashed"
        
        #expect(sut.stringValue == "Hello Stashed")
    }
    
    @Test
    func `Non-optional Int returns default value when not set`() {
        let (sut, cleanup) = makeStashedTestView()
        defer { cleanup() }
        
        #expect(sut.intValue == 0)
    }
    
    @Test
    func `Non-optional Int can be set and retrieved`() {
        let (sut, cleanup) = makeStashedTestView()
        defer { cleanup() }
        
        sut.intValue = 999
        
        #expect(sut.intValue == 999)
    }

    @Test
    func `AppStorage-style Stashed declaration works for default and optional primitive values`() {
        let key1 = "appStorageStyle.stashed.int"
        let key2 = "appStorageStyle.stashed.optionalInt"
        defer {
            UserDefaults.standard.removeObject(forKey: key1)
            UserDefaults.standard.removeObject(forKey: key2)
        }

        struct AppStorageStyleView: View {
            @Stashed("appStorageStyle.stashed.int") var value: Int = 9
            @Stashed("appStorageStyle.stashed.optionalInt") var optionalValue: Int?

            var body: some View { EmptyView() }
        }

        let sut = AppStorageStyleView()

        #expect(sut.value == 9)
        #expect(sut.optionalValue == nil)

        sut.value = 42
        sut.optionalValue = 7

        #expect(sut.value == 42)
        #expect(sut.optionalValue == 7)
    }
    
    @Test
    func `Non-optional Bool returns default value when not set`() {
        let (sut, cleanup) = makeStashedTestView()
        defer { cleanup() }
        
        #expect(sut.boolValue == false)
    }
    
    @Test
    func `Non-optional Bool can be set and retrieved`() {
        let (sut, cleanup) = makeStashedTestView()
        defer { cleanup() }
        
        sut.boolValue = true
        
        #expect(sut.boolValue == true)
    }
    
    @Test
    func `Non-optional Double returns default value when not set`() {
        let (sut, cleanup) = makeStashedTestView()
        defer { cleanup() }
        
        #expect(sut.doubleValue == 0.0)
    }
    
    @Test
    func `Non-optional Double can be set and retrieved`() {
        let (sut, cleanup) = makeStashedTestView()
        defer { cleanup() }
        
        sut.doubleValue = 3.14159
        
        #expect(sut.doubleValue == 3.14159)
    }
    
    @Test
    func `Non-optional Date can be set and retrieved`() {
        let (sut, cleanup) = makeStashedTestView()
        defer { cleanup() }
        
        let testDate = Date(timeIntervalSince1970: 1234567890)
        sut.dateValue = testDate
        
        #expect(sut.dateValue.timeIntervalSince1970 == testDate.timeIntervalSince1970)
    }
    
    @Test
    func `Non-optional Data can be set and retrieved`() {
        let (sut, cleanup) = makeStashedTestView()
        defer { cleanup() }
        
        let testData = Data([0x01, 0x02, 0x03, 0x04])
        sut.dataValue = testData
        
        #expect(sut.dataValue == testData)
    }
    
    // MARK: - Primitive Types - Optional
    
    @Test
    func `Optional String returns nil when not set`() {
        let (sut, cleanup) = makeStashedTestView()
        defer { cleanup() }
        
        #expect(sut.optionalStringValue == nil)
    }
    
    @Test
    func `Optional String can be set and retrieved`() {
        let (sut, cleanup) = makeStashedTestView()
        defer { cleanup() }
        
        sut.optionalStringValue = "Optional Stashed Value"
        
        #expect(sut.optionalStringValue == "Optional Stashed Value")
    }
    
    @Test
    func `Optional String can be set to nil after having a value`() {
        let (sut, cleanup) = makeStashedTestView()
        defer { cleanup() }
        
        sut.optionalStringValue = "Some Value"
        #expect(sut.optionalStringValue == "Some Value")
        
        sut.optionalStringValue = nil
        #expect(sut.optionalStringValue == nil)
    }
    
    @Test
    func `Optional String removes key from UserDefaults when set to nil`() {
        let (userDefaults, cleanup) = makeUserDefaults(suiteName: "stashed.optional.string.remove")
        defer { cleanup() }
        
        let sut = StashedTestView(userDefaults: userDefaults)
        
        sut.optionalStringValue = "Value"
        #expect(userDefaults.object(forKey: "stashedOptionalString") != nil)
        
        sut.optionalStringValue = nil
        #expect(userDefaults.object(forKey: "stashedOptionalString") == nil)
    }
    
    @Test
    func `Optional Int returns nil when not set`() {
        let (sut, cleanup) = makeStashedTestView()
        defer { cleanup() }
        
        #expect(sut.optionalIntValue == nil)
    }
    
    @Test
    func `Optional Int can be set and retrieved`() {
        let (sut, cleanup) = makeStashedTestView()
        defer { cleanup() }
        
        sut.optionalIntValue = 42
        
        #expect(sut.optionalIntValue == 42)
    }
    
    @Test
    func `Optional Int can be set to nil after having a value`() {
        let (sut, cleanup) = makeStashedTestView()
        defer { cleanup() }
        
        sut.optionalIntValue = 100
        #expect(sut.optionalIntValue == 100)
        
        sut.optionalIntValue = nil
        #expect(sut.optionalIntValue == nil)
    }
    
    @Test
    func `Optional Bool returns nil when not set`() {
        let (sut, cleanup) = makeStashedTestView()
        defer { cleanup() }
        
        #expect(sut.optionalBoolValue == nil)
    }
    
    @Test
    func `Optional Bool can be set and retrieved`() {
        let (sut, cleanup) = makeStashedTestView()
        defer { cleanup() }
        
        sut.optionalBoolValue = true
        
        #expect(sut.optionalBoolValue == true)
    }
    
    @Test
    func `Optional Double returns nil when not set`() {
        let (sut, cleanup) = makeStashedTestView()
        defer { cleanup() }
        
        #expect(sut.optionalDoubleValue == nil)
    }
    
    @Test
    func `Optional Double can be set and retrieved`() {
        let (sut, cleanup) = makeStashedTestView()
        defer { cleanup() }
        
        sut.optionalDoubleValue = 2.71828
        
        #expect(sut.optionalDoubleValue == 2.71828)
    }
    
    @Test
    func `Optional Date returns nil when not set`() {
        let (sut, cleanup) = makeStashedTestView()
        defer { cleanup() }
        
        #expect(sut.optionalDateValue == nil)
    }
    
    @Test
    func `Optional Date can be set and retrieved`() {
        let (sut, cleanup) = makeStashedTestView()
        defer { cleanup() }
        
        let testDate = Date(timeIntervalSince1970: 9876543210)
        sut.optionalDateValue = testDate
        
        #expect(sut.optionalDateValue?.timeIntervalSince1970 == testDate.timeIntervalSince1970)
    }
    
    @Test
    func `Optional Data returns nil when not set`() {
        let (sut, cleanup) = makeStashedTestView()
        defer { cleanup() }
        
        #expect(sut.optionalDataValue == nil)
    }
    
    @Test
    func `Optional Data can be set and retrieved`() {
        let (sut, cleanup) = makeStashedTestView()
        defer { cleanup() }
        
        let testData = Data([0xFF, 0xEE, 0xDD])
        sut.optionalDataValue = testData
        
        #expect(sut.optionalDataValue == testData)
    }
    
    // MARK: - Codable Types - Non-Optional
    
    @Test
    func `Non-optional Codable returns default value when not set`() {
        let (sut, cleanup) = makeStashedTestView()
        defer { cleanup() }
        
        #expect(sut.userProfile == UserProfile(name: "Default", age: 0, email: "default@test.com"))
    }
    
    @Test
    func `Non-optional Codable can be set and retrieved`() {
        let (sut, cleanup) = makeStashedTestView()
        defer { cleanup() }
        
        let profile = UserProfile(name: "Alice", age: 30, email: "alice@example.com")
        sut.userProfile = profile
        
        #expect(sut.userProfile == profile)
    }
    
    @Test
    func `Non-optional Codable persists across instances`() {
        let (userDefaults, cleanup) = makeUserDefaults(suiteName: "stashed.codable.persist")
        defer { cleanup() }
        
        let sut1 = StashedTestView(userDefaults: userDefaults)
        let profile = UserProfile(name: "Bob", age: 35, email: "bob@example.com")
        sut1.userProfile = profile
        
        let sut2 = StashedTestView(userDefaults: userDefaults)
        #expect(sut2.userProfile == profile)
    }
    
    @Test
    func `Non-optional Codable returns default when stored data is corrupted`() {
        let (userDefaults, cleanup) = makeUserDefaults(suiteName: "stashed.codable.corrupted")
        defer { cleanup() }
        
        let corruptedData = Data("not valid json".utf8)
        userDefaults.set(corruptedData, forKey: "stashedUserProfile")
        
        let sut = StashedTestView(userDefaults: userDefaults)
        
        #expect(sut.userProfile == UserProfile(name: "Default", age: 0, email: "default@test.com"))
    }
    
    // MARK: - Codable Types - Optional
    
    @Test
    func `Optional Codable returns nil when not set`() {
        let (sut, cleanup) = makeStashedTestView()
        defer { cleanup() }
        
        #expect(sut.optionalUserProfile == nil)
    }
    
    @Test
    func `Optional Codable can be set and retrieved`() {
        let (sut, cleanup) = makeStashedTestView()
        defer { cleanup() }
        
        let profile = UserProfile(name: "Charlie", age: 28, email: "charlie@example.com")
        sut.optionalUserProfile = profile
        
        #expect(sut.optionalUserProfile == profile)
    }
    
    @Test
    func `Optional Codable can be set to nil after having a value`() {
        let (sut, cleanup) = makeStashedTestView()
        defer { cleanup() }
        
        sut.optionalUserProfile = UserProfile(name: "Diana", age: 32, email: "diana@example.com")
        #expect(sut.optionalUserProfile != nil)
        
        sut.optionalUserProfile = nil
        #expect(sut.optionalUserProfile == nil)
    }
    
    @Test
    func `Optional Codable removes key from UserDefaults when set to nil`() {
        let (userDefaults, cleanup) = makeUserDefaults(suiteName: "stashed.optional.codable.remove")
        defer { cleanup() }
        
        let sut = StashedTestView(userDefaults: userDefaults)
        sut.optionalUserProfile = UserProfile(name: "Eve", age: 29, email: "eve@example.com")
        #expect(userDefaults.data(forKey: "stashedOptionalUserProfile") != nil)
        
        sut.optionalUserProfile = nil
        #expect(userDefaults.data(forKey: "stashedOptionalUserProfile") == nil)
    }
    
    @Test
    func `Optional Codable returns nil when stored data is corrupted`() {
        let (userDefaults, cleanup) = makeUserDefaults(suiteName: "stashed.optional.codable.corrupted")
        defer { cleanup() }
        
        let corruptedData = Data("invalid json".utf8)
        userDefaults.set(corruptedData, forKey: "stashedOptionalUserProfile")
        
        let sut = StashedTestView(userDefaults: userDefaults)
        
        #expect(sut.optionalUserProfile == nil)
    }
    
    // MARK: - RawRepresentable (Enums) - Non-Optional
    
    @Test
    func `Non-optional String-based enum returns default value when not set`() {
        let (sut, cleanup) = makeStashedTestView()
        defer { cleanup() }
        
        #expect(sut.theme == .system)
    }
    
    @Test
    func `Non-optional String-based enum can be set and retrieved`() {
        let (sut, cleanup) = makeStashedTestView()
        defer { cleanup() }
        
        sut.theme = .dark
        
        #expect(sut.theme == .dark)
    }
    
    @Test
    func `Non-optional String-based enum stores raw value in UserDefaults`() {
        let (userDefaults, cleanup) = makeUserDefaults(suiteName: "stashed.theme.rawvalue")
        defer { cleanup() }
        
        let sut = StashedTestView(userDefaults: userDefaults)
        sut.theme = .light
        
        let storedValue = userDefaults.object(forKey: "stashedTheme") as? String
        #expect(storedValue == Theme.light.rawValue)
        #expect(storedValue == "light")
    }
    
    @Test
    func `Non-optional String-based enum persists across instances`() {
        let (userDefaults, cleanup) = makeUserDefaults(suiteName: "stashed.theme.persist")
        defer { cleanup() }
        
        let sut1 = StashedTestView(userDefaults: userDefaults)
        sut1.theme = .dark
        
        let sut2 = StashedTestView(userDefaults: userDefaults)
        #expect(sut2.theme == .dark)
    }
    
    @Test
    func `Non-optional Int-based enum returns default value when not set`() {
        let (sut, cleanup) = makeStashedTestView()
        defer { cleanup() }
        
        #expect(sut.priority == .medium)
    }
    
    @Test
    func `Non-optional Int-based enum can be set and retrieved`() {
        let (sut, cleanup) = makeStashedTestView()
        defer { cleanup() }
        
        sut.priority = .high
        
        #expect(sut.priority == .high)
    }
    
    @Test
    func `Non-optional Int-based enum stores raw value in UserDefaults`() {
        let (userDefaults, cleanup) = makeUserDefaults(suiteName: "stashed.priority.rawvalue")
        defer { cleanup() }
        
        let sut = StashedTestView(userDefaults: userDefaults)
        sut.priority = .critical
        
        let storedValue = userDefaults.object(forKey: "stashedPriority") as? Int
        #expect(storedValue == Priority.critical.rawValue)
        #expect(storedValue == 4)
    }
    
    @Test
    func `Non-optional Int-based enum persists across instances`() {
        let (userDefaults, cleanup) = makeUserDefaults(suiteName: "stashed.priority.persist")
        defer { cleanup() }
        
        let sut1 = StashedTestView(userDefaults: userDefaults)
        sut1.priority = .low
        
        let sut2 = StashedTestView(userDefaults: userDefaults)
        #expect(sut2.priority == .low)
    }
    
    // MARK: - RawRepresentable (Enums) - Optional
    
    @Test
    func `Optional String-based enum returns nil when not set`() {
        let (sut, cleanup) = makeStashedTestView()
        defer { cleanup() }
        
        #expect(sut.optionalTheme == nil)
    }
    
    @Test
    func `Optional String-based enum can be set and retrieved`() {
        let (sut, cleanup) = makeStashedTestView()
        defer { cleanup() }
        
        sut.optionalTheme = .dark
        
        #expect(sut.optionalTheme == .dark)
    }
    
    @Test
    func `Optional String-based enum can be set to nil after having a value`() {
        let (sut, cleanup) = makeStashedTestView()
        defer { cleanup() }
        
        sut.optionalTheme = .light
        #expect(sut.optionalTheme == .light)
        
        sut.optionalTheme = nil
        #expect(sut.optionalTheme == nil)
    }
    
    @Test
    func `Optional String-based enum removes key from UserDefaults when set to nil`() {
        let (userDefaults, cleanup) = makeUserDefaults(suiteName: "stashed.optional.theme.remove")
        defer { cleanup() }
        
        let sut = StashedTestView(userDefaults: userDefaults)
        sut.optionalTheme = .dark
        #expect(userDefaults.object(forKey: "stashedOptionalTheme") != nil)
        
        sut.optionalTheme = nil
        #expect(userDefaults.object(forKey: "stashedOptionalTheme") == nil)
    }
    
    @Test
    func `Optional Int-based enum returns nil when not set`() {
        let (sut, cleanup) = makeStashedTestView()
        defer { cleanup() }
        
        #expect(sut.optionalPriority == nil)
    }
    
    @Test
    func `Optional Int-based enum can be set and retrieved`() {
        let (sut, cleanup) = makeStashedTestView()
        defer { cleanup() }
        
        sut.optionalPriority = .high
        
        #expect(sut.optionalPriority == .high)
    }
    
    @Test
    func `Optional Int-based enum can be set to nil after having a value`() {
        let (sut, cleanup) = makeStashedTestView()
        defer { cleanup() }
        
        sut.optionalPriority = .critical
        #expect(sut.optionalPriority == .critical)
        
        sut.optionalPriority = nil
        #expect(sut.optionalPriority == nil)
    }
    
    @Test
    func `Optional Int-based enum removes key from UserDefaults when set to nil`() {
        let (userDefaults, cleanup) = makeUserDefaults(suiteName: "stashed.optional.priority.remove")
        defer { cleanup() }
        
        let sut = StashedTestView(userDefaults: userDefaults)
        sut.optionalPriority = .high
        #expect(userDefaults.object(forKey: "stashedOptionalPriority") != nil)
        
        sut.optionalPriority = nil
        #expect(userDefaults.object(forKey: "stashedOptionalPriority") == nil)
    }
    
    // MARK: - Collections
    
    @Test
    func `Array of Strings can be stored and retrieved`() {
        let (sut, cleanup) = makeStashedTestView()
        defer { cleanup() }
        
        let testArray = ["apple", "banana", "cherry"]
        sut.stringArrayValue = testArray
        
        #expect(sut.stringArrayValue == testArray)
    }
    
    @Test
    func `Empty array can be stored and retrieved`() {
        let (sut, cleanup) = makeStashedTestView()
        defer { cleanup() }
        
        sut.stringArrayValue = ["item"]
        sut.stringArrayValue = []
        
        #expect(sut.stringArrayValue == [])
    }
    
    @Test
    func `Dictionary can be stored and retrieved`() {
        let (sut, cleanup) = makeStashedTestView()
        defer { cleanup() }
        
        let testDict = ["key1": "value1", "key2": "value2"]
        sut.dictionaryValue = testDict
        
        #expect(sut.dictionaryValue == testDict)
    }
    
    // MARK: - SwiftUI Binding Integration
    
    @Test
    func `Projected value provides SwiftUI Binding`() {
        let (sut, cleanup) = makeStashedTestView()
        defer { cleanup() }
        
        let binding = sut.$stringValue
        
        binding.wrappedValue = "Bound Value"
        
        #expect(sut.stringValue == "Bound Value")
        #expect(binding.wrappedValue == "Bound Value")
    }
    
    @Test
    func `Binding can be used for two-way updates`() {
        let (sut, cleanup) = makeStashedTestView()
        defer { cleanup() }
        
        let binding = sut.$intValue
        
        // Update via binding
        binding.wrappedValue = 50
        #expect(sut.intValue == 50)
        
        // Update via property
        sut.intValue = 75
        #expect(binding.wrappedValue == 75)
    }
    
    @Test
    func `Multiple properties with same type use different keys`() {
        let (sut, cleanup) = makeStashedTestView()
        defer { cleanup() }
        
        sut.stringValue = "First String"
        sut.anotherStringValue = "Second String"
        
        #expect(sut.stringValue == "First String")
        #expect(sut.anotherStringValue == "Second String")
    }
    
    // MARK: - Persistence & Cross-Instance Updates
    
    // Note: Memory management tests are not applicable for @Stashed since it's a SwiftUI View (struct).
    // SwiftUI manages the lifecycle of Views and their DynamicProperty storage automatically.
    
    @Test
    func `Changes in one instance are reflected in another instance`() {
        let (userDefaults, cleanup) = makeUserDefaults(suiteName: "stashed.cross.instance")
        defer { cleanup() }
        
        let sut1 = StashedTestView(userDefaults: userDefaults)
        let sut2 = StashedTestView(userDefaults: userDefaults)
        
        sut1.stringValue = "Shared Value"
        
        // Both wrappers share the same cached observer for this store, key, and value type.
        #expect(sut2.stringValue == "Shared Value")
    }
    
    @Test
    func `Different keys store independent values`() {
        let (sut, cleanup) = makeStashedTestView()
        defer { cleanup() }
        
        sut.stringValue = "String Value"
        sut.intValue = 42
        sut.boolValue = true
        sut.doubleValue = 3.14
        
        #expect(sut.stringValue == "String Value")
        #expect(sut.intValue == 42)
        #expect(sut.boolValue == true)
        #expect(sut.doubleValue == 3.14)
    }
    
    // MARK: - Error Handling
    
    @Test
    func `Codable with missing fields returns default value`() {
        let (userDefaults, cleanup) = makeUserDefaults(suiteName: "stashed.codable.missing")
        defer { cleanup() }
        
        let incompleteJSON = """
        {"name": "Incomplete"}
        """.data(using: .utf8)!
        userDefaults.set(incompleteJSON, forKey: "stashedUserProfile")
        
        let sut = StashedTestView(userDefaults: userDefaults)
        
        #expect(sut.userProfile == UserProfile(name: "Default", age: 0, email: "default@test.com"))
    }
    
    @Test
    func `Codable with wrong type returns default value`() {
        let (userDefaults, cleanup) = makeUserDefaults(suiteName: "stashed.codable.wrongtype")
        defer { cleanup() }
        
        let wrongTypeJSON = """
        {"name": "John", "age": "not a number", "email": "test@example.com"}
        """.data(using: .utf8)!
        userDefaults.set(wrongTypeJSON, forKey: "stashedUserProfile")
        
        let sut = StashedTestView(userDefaults: userDefaults)
        
        #expect(sut.userProfile == UserProfile(name: "Default", age: 0, email: "default@test.com"))
    }
    
    @Test
    func `RawRepresentable with invalid raw value returns default`() {
        let (userDefaults, cleanup) = makeUserDefaults(suiteName: "stashed.enum.invalid")
        defer { cleanup() }
        
        // Store an invalid raw value
        userDefaults.set("invalid_theme", forKey: "stashedTheme")
        
        let sut = StashedTestView(userDefaults: userDefaults)
        
        #expect(sut.theme == .system)
    }
}

// MARK: - Test Helpers

@MainActor
private func makeStashedTestView(
    suiteName: String = UUID().uuidString
) -> (sut: StashedTestView, cleanup: @Sendable () -> Void) {
    let (userDefaults, cleanup) = makeUserDefaults(suiteName: suiteName)
    let sut = StashedTestView(userDefaults: userDefaults)
    return (sut, cleanup)
}

// MARK: - Test View

@MainActor
private struct StashedTestView: View {
    let userDefaults: UserDefaults
    
    // Primitive types - Non-optional
    @Stashed var stringValue: String
    @Stashed var anotherStringValue: String
    @Stashed var intValue: Int
    @Stashed var boolValue: Bool
    @Stashed var doubleValue: Double
    @Stashed var dateValue: Date
    @Stashed var dataValue: Data
    
    // Primitive types - Optional
    @Stashed var optionalStringValue: String?
    @Stashed var optionalIntValue: Int?
    @Stashed var optionalBoolValue: Bool?
    @Stashed var optionalDoubleValue: Double?
    @Stashed var optionalDateValue: Date?
    @Stashed var optionalDataValue: Data?
    
    // Codable types
    @Stashed var userProfile: UserProfile
    @Stashed var optionalUserProfile: UserProfile?
    
    // RawRepresentable types (enums)
    @Stashed var theme: Theme
    @Stashed var priority: Priority
    @Stashed var optionalTheme: Theme?
    @Stashed var optionalPriority: Priority?
    
    // Collections
    @Stashed var stringArrayValue: [String]
    @Stashed var dictionaryValue: [String: String]
    
    var body: some View {
        EmptyView()
    }
    
    init(userDefaults: UserDefaults) {
        self.userDefaults = userDefaults
        
        // Primitive types - Non-optional
        _stringValue = Stashed(key: "stashedString", defaultValue: "default", store: userDefaults)
        _anotherStringValue = Stashed(key: "stashedAnotherString", defaultValue: "", store: userDefaults)
        _intValue = Stashed(key: "stashedInt", defaultValue: 0, store: userDefaults)
        _boolValue = Stashed(key: "stashedBool", defaultValue: false, store: userDefaults)
        _doubleValue = Stashed(key: "stashedDouble", defaultValue: 0.0, store: userDefaults)
        _dateValue = Stashed(key: "stashedDate", defaultValue: Date(timeIntervalSince1970: 0), store: userDefaults)
        _dataValue = Stashed(key: "stashedData", defaultValue: Data(), store: userDefaults)
        
        // Primitive types - Optional
        _optionalStringValue = Stashed(key: "stashedOptionalString", store: userDefaults)
        _optionalIntValue = Stashed(key: "stashedOptionalInt", store: userDefaults)
        _optionalBoolValue = Stashed(key: "stashedOptionalBool", store: userDefaults)
        _optionalDoubleValue = Stashed(key: "stashedOptionalDouble", store: userDefaults)
        _optionalDateValue = Stashed(key: "stashedOptionalDate", store: userDefaults)
        _optionalDataValue = Stashed(key: "stashedOptionalData", store: userDefaults)
        
        // Codable types
        _userProfile = Stashed(
            codable: "stashedUserProfile",
            defaultValue: UserProfile(name: "Default", age: 0, email: "default@test.com"),
            store: userDefaults
        )
        _optionalUserProfile = Stashed(codable: "stashedOptionalUserProfile", store: userDefaults)
        
        // RawRepresentable types (enums)
        _theme = Stashed(key: "stashedTheme", defaultValue: .system, store: userDefaults)
        _priority = Stashed(key: "stashedPriority", defaultValue: .medium, store: userDefaults)
        _optionalTheme = Stashed(key: "stashedOptionalTheme", store: userDefaults)
        _optionalPriority = Stashed(key: "stashedOptionalPriority", store: userDefaults)
        
        // Collections
        _stringArrayValue = Stashed(key: "stashedStringArray", defaultValue: [], store: userDefaults)
        _dictionaryValue = Stashed(key: "stashedDictionary", defaultValue: [:], store: userDefaults)
    }
}
