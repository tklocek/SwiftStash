//
//  StashTests.swift
//  SwiftStash
//
// Copyright (c) 2026 SwiftStash contributors
// SPDX-License-Identifier: MIT
//

import Foundation
import Testing
@testable import SwiftStash

/// Core functionality tests for @Stash property wrapper.
///
/// Tests cover:
/// - Primitive types (String, Int, Bool)
/// - Codable types
/// - Optional values
/// - Persistence across instances
/// - Error handling
/// - Memory management
struct StashTests {
    
    // MARK: - Primitive Types
    
    @Test
    func `Non-optional String returns default value when not set`() {
        let (sut, cleanup) = makeTestStorage()
        defer { cleanup() }
        
        #expect(sut.stringValue == "default")
    }
    
    @Test
    func `Non-optional String can be set and retrieved`() {
        let (sut, cleanup) = makeTestStorage()
        defer { cleanup() }
        
        sut.stringValue = "Hello World"
        
        #expect(sut.stringValue == "Hello World")
    }
    
    @Test
    func `Non-optional Int can be set and retrieved`() {
        let (sut, cleanup) = makeTestStorage()
        defer { cleanup() }
        
        sut.intValue = 42
        
        #expect(sut.intValue == 42)
    }

    @Test
    func `AppStorage-style Stash declaration works for default and optional primitive values`() {
        let key1 = "appStorageStyle.stash.int"
        let key2 = "appStorageStyle.stash.optionalInt"
        defer {
            UserDefaults.standard.removeObject(forKey: key1)
            UserDefaults.standard.removeObject(forKey: key2)
        }

        struct AppStorageStyleStorage {
            @Stash("appStorageStyle.stash.int") var value: Int = 9
            @Stash("appStorageStyle.stash.optionalInt") var optionalValue: Int?
        }

        // `let` works because @Stash setters are nonmutating.
        let sut = AppStorageStyleStorage()

        #expect(sut.value == 9)
        #expect(sut.optionalValue == nil)

        sut.value = 42
        sut.optionalValue = 7

        #expect(sut.value == 42)
        #expect(sut.optionalValue == 7)
    }
    
    // MARK: - Optional Primitives
    
    @Test
    func `Optional String returns nil when not set`() {
        let (sut, cleanup) = makeTestStorage()
        defer { cleanup() }
        
        #expect(sut.optionalStringValue == nil)
    }
    
    @Test
    func `Optional String can be set and retrieved`() {
        let (sut, cleanup) = makeTestStorage()
        defer { cleanup() }
        
        sut.optionalStringValue = "Optional Value"
        
        #expect(sut.optionalStringValue == "Optional Value")
    }
    
    @Test
    func `Optional String can be set to nil after having a value`() {
        let (sut, cleanup) = makeTestStorage()
        defer { cleanup() }
        
        sut.optionalStringValue = "Some Value"
        #expect(sut.optionalStringValue == "Some Value")
        
        sut.optionalStringValue = nil
        #expect(sut.optionalStringValue == nil)
    }
    
    @Test
    func `Optional String removes key from UserDefaults when set to nil`() {
        let (userDefaults, cleanup) = makeUserDefaults(suiteName: "test.optional.string.remove")
        defer { cleanup() }
        
        let storage = TestStorage(userDefaults: userDefaults)
        
        storage.optionalStringValue = "Value"
        #expect(userDefaults.object(forKey: "testOptionalString") != nil)
        
        storage.optionalStringValue = nil
        #expect(userDefaults.object(forKey: "testOptionalString") == nil)
    }
    
    @Test
    func `Non-optional String persists across instances`() {
        let (userDefaults, cleanup) = makeUserDefaults(suiteName: "test.string.persist")
        defer { cleanup() }
        
        let storage1 = TestStorage(userDefaults: userDefaults)
        storage1.stringValue = "Persisted Value"
        
        let storage2 = TestStorage(userDefaults: userDefaults)
        #expect(storage2.stringValue == "Persisted Value")
    }
    
    // MARK: - Codable Types
    
    @Test
    func `Codable struct returns default value when not set`() {
        let (sut, cleanup) = makeTestStorage()
        defer { cleanup() }
        
        #expect(sut.userProfile == TestStorage.userProfileDefaultValue)
    }
    
    @Test
    func `Codable struct can be set and retrieved`() {
        let (sut, cleanup) = makeTestStorage()
        defer { cleanup() }
        
        let profile = UserProfile(name: "John Smith", age: 30, email: "john@example.com")
        sut.userProfile = profile
        
        #expect(sut.userProfile == profile)
    }
    
    @Test
    func `Optional Codable struct returns nil when not set`() {
        let (sut, cleanup) = makeTestStorage()
        defer { cleanup() }
        
        #expect(sut.optionalUserProfile == nil)
    }
    
    @Test
    func `Optional Codable struct can be set to nil after having a value`() {
        let (sut, cleanup) = makeTestStorage()
        defer { cleanup() }
        
        sut.optionalUserProfile = UserProfile(name: "David Evans", age: 40, email: "david@example.com")
        #expect(sut.optionalUserProfile != nil)
        
        sut.optionalUserProfile = nil
        #expect(sut.optionalUserProfile == nil)
    }
    
    @Test
    func `Optional Codable struct removes key from UserDefaults when set to nil`() {
        let (userDefaults, cleanup) = makeUserDefaults(suiteName: "optional.codable.remove.test")
        defer { cleanup() }
        
        let sut = TestStorage(userDefaults: userDefaults)
        sut.optionalUserProfile = UserProfile(name: "Emma Fisher", age: 29, email: "emma@example.com")
        #expect(userDefaults.data(forKey: "testOptionalUserProfile") != nil)
        
        sut.optionalUserProfile = nil
        #expect(userDefaults.data(forKey: "testOptionalUserProfile") == nil)
    }
    
    @Test
    func `Codable struct persists across instances`() {
        let (userDefaults, cleanup) = makeUserDefaults(suiteName: "codable.persistence.test")
        defer { cleanup() }
        
        let sut1 = TestStorage(userDefaults: userDefaults)
        let profile = UserProfile(name: "Jane Doe", age: 25, email: "jane@example.com")
        sut1.userProfile = profile
        
        let sut2 = TestStorage(userDefaults: userDefaults)
        #expect(sut2.userProfile == profile)
    }
    
    @Test
    func `Read different type Codable than stored returns default value`() throws {
        let (userDefaults, cleanup) = makeUserDefaults(suiteName: "codable.wrong.type.test")
        defer { cleanup() }
        
        let wrongProfile = DifferentProfile(firstName: "John", lastName: "Doe", initials: "JD")
        
        let data = try JSONEncoder().encode(wrongProfile)
        userDefaults.set(data, forKey: TestStorage.userProfileKey)
        
        let sut = TestStorage(userDefaults: userDefaults)
        
        #expect(sut.userProfile == TestStorage.userProfileDefaultValue)
    }
    
    // MARK: - Collections
    
    @Test
    func `String array can be stored and retrieved`() {
        let (sut, cleanup) = makeTestStorage()
        defer { cleanup() }
        
        let testArray = ["one", "two", "three"]
        sut.stringArrayValue = testArray
        
        #expect(sut.stringArrayValue == testArray)
    }
    
    @Test
    func `Dictionary can be stored and retrieved`() {
        let (sut, cleanup) = makeTestStorage()
        defer { cleanup() }
        
        let testDict = ["key1": "value1", "key2": "value2"]
        sut.dictionaryValue = testDict
        
        #expect(sut.dictionaryValue == testDict)
    }
    
    // MARK: - Multiple Keys
    
    @Test
    func `Different keys store independent values`() {
        let (sut, cleanup) = makeTestStorage()
        defer { cleanup() }
        
        sut.stringValue = "String Value"
        sut.intValue = 42
        sut.boolValue = true
        
        #expect(sut.stringValue == "String Value")
        #expect(sut.intValue == 42)
        #expect(sut.boolValue == true)
    }
    
    @Test
    func `Multiple properties with same type use different keys`() {
        let (sut, cleanup) = makeTestStorage()
        defer { cleanup() }
        
        sut.stringValue = "First"
        sut.anotherStringValue = "Second"
        
        #expect(sut.stringValue == "First")
        #expect(sut.anotherStringValue == "Second")
    }
    
    @Test
    func `Unicode characters are preserved`() {
        let (sut, cleanup) = makeTestStorage()
        defer { cleanup() }

        sut.stringValue = "Hello 世界 🌍 café"

        #expect(sut.stringValue == "Hello 世界 🌍 café")
    }

    @Test
    func `Empty string can be stored and retrieved`() {
        let (sut, cleanup) = makeTestStorage()
        defer { cleanup() }

        sut.stringValue = ""

        #expect(sut.stringValue == "")
    }
    
    // MARK: - Error Handling and Edge Cases
    
    @Test
    func `Codable struct returns default when stored data is corrupted`() {
        let (userDefaults, cleanup) = makeUserDefaults(suiteName: "test.codable.corrupted")
        defer { cleanup() }
        
        let corruptedData = Data("not valid json".utf8)
        userDefaults.set(corruptedData, forKey: TestStorage.userProfileKey)
        
        let sut = TestStorage(userDefaults: userDefaults)
        
        #expect(sut.userProfile == TestStorage.userProfileDefaultValue)
    }
    
    @Test
    func `Optional Codable returns nil when stored data is corrupted`() {
        let (userDefaults, cleanup) = makeUserDefaults(suiteName: "test.optional.codable.corrupted")
        defer { cleanup() }
        
        let corruptedData = Data("invalid json data".utf8)
        userDefaults.set(corruptedData, forKey: TestStorage.optionalUserProfileKey)
        
        let sut = TestStorage(userDefaults: userDefaults)
        
        #expect(sut.optionalUserProfile == nil)
    }
    
    @Test
    func `Codable struct with missing required fields returns default`() {
        let (userDefaults, cleanup) = makeUserDefaults(suiteName: "test.codable.missingfields")
        defer { cleanup() }
        
        let incompleteJSON = """
        {"name": "John"}
        """.data(using: .utf8)!
        userDefaults.set(incompleteJSON, forKey: TestStorage.userProfileKey)
        
        let sut = TestStorage(userDefaults: userDefaults)
        
        #expect(sut.userProfile == TestStorage.userProfileDefaultValue)
    }
    
    @Test
    func `Codable struct handles invalid type for field`() {
        let (userDefaults, cleanup) = makeUserDefaults(suiteName: "test.codable.invalidfieldtype")
        defer { cleanup() }
        
        let invalidTypeJSON = """
        {"name": "John", "age": "not a number", "email": "test@example.com"}
        """.data(using: .utf8)!
        userDefaults.set(invalidTypeJSON, forKey: "testUserProfile")
        
        let sut = TestStorage(userDefaults: userDefaults)
        
        #expect(sut.userProfile == TestStorage.userProfileDefaultValue)
    }
    
    @Test
    func `Encoding failure does not write anything for an absent key`() {
        let (userDefaults, cleanup) = makeUserDefaults(suiteName: "test.codable.encodefails")
        defer { cleanup() }

        let storage = FailingEncodableStorage(userDefaults: userDefaults)

        storage.failingValue = FailingEncodable()

        #expect(userDefaults.data(forKey: FailingEncodableStorage.failingValueKey) == nil)
    }

    @Test
    func `Encoding failure preserves the previously stored value`() {
        let (userDefaults, cleanup) = makeUserDefaults(suiteName: "test.codable.encodefails.preserve")
        defer { cleanup() }

        let previousData = Data("last-known-good".utf8)
        userDefaults.set(previousData, forKey: FailingEncodableStorage.failingValueKey)

        let storage = FailingEncodableStorage(userDefaults: userDefaults)

        storage.failingValue = FailingEncodable()

        #expect(userDefaults.data(forKey: FailingEncodableStorage.failingValueKey) == previousData)
    }
    
    // MARK: - Memory Management Tests
    
    @Test
    func `TestStorage instance is deallocated when no longer referenced`() {
        let (userDefaults, cleanup) = makeUserDefaults(suiteName: "test.memory.leak")
        defer { cleanup() }
        
        weak var weakSUT: TestStorage?
        
        autoreleasepool {
            let sut = TestStorage(userDefaults: userDefaults)
            weakSUT = sut
            
            sut.stringValue = "test"
            sut.intValue = 42
            sut.userProfile = UserProfile(name: "Test User", age: 25, email: "test@example.com")
            
            #expect(weakSUT != nil)
        }
        
        #expect(weakSUT == nil)
    }
    
    // MARK: - RawRepresentable (Enum) Tests

    @Test
    func `String-based enum can be set and retrieved`() {
        let (sut, cleanup) = makeTestStorage()
        defer { cleanup() }
        
        sut.theme = .dark
        #expect(sut.theme == .dark)
        
        sut.theme = .light
        #expect(sut.theme == .light)
    }
    
    @Test
    func `String-based enum returns default value when not set`() {
        let (sut, cleanup) = makeTestStorage()
        defer { cleanup() }
        
        #expect(sut.theme == .system)
    }
    
    @Test
    func `String-based enum stores raw value in UserDefaults`() {
        let (userDefaults, cleanup) = makeUserDefaults(suiteName: "test.theme.rawvalue")
        defer { cleanup() }
        
        let sut = TestStorage(userDefaults: userDefaults)
        sut.theme = .dark
        
        // Verify the raw value (String) is stored, not the enum itself
        let storedValue = userDefaults.object(forKey: "testTheme") as? String
        #expect(storedValue == Theme.dark.rawValue)
        #expect(storedValue == "dark")
    }
    
    @Test
    func `Int-based enum can be set and retrieved`() {
        let (sut, cleanup) = makeTestStorage()
        defer { cleanup() }
        
        sut.priority = .high
        #expect(sut.priority == .high)
        
        sut.priority = .low
        #expect(sut.priority == .low)
    }
    
    @Test
    func `Int-based enum returns default value when not set`() {
        let (sut, cleanup) = makeTestStorage()
        defer { cleanup() }
        
        #expect(sut.priority == .medium)
    }
    
    @Test
    func `Int-based enum stores raw value in UserDefaults`() {
        let (userDefaults, cleanup) = makeUserDefaults(suiteName: "test.priority.rawvalue")
        defer { cleanup() }
        
        let sut = TestStorage(userDefaults: userDefaults)
        sut.priority = .critical
        
        // Verify the raw value (Int) is stored, not the enum itself
        let storedValue = userDefaults.object(forKey: "testPriority") as? Int
        #expect(storedValue == Priority.critical.rawValue)
        #expect(storedValue == 4)
    }
    
    @Test
    func `Optional String-based enum starts nil, can be set and cleared`() {
        let (sut, cleanup) = makeTestStorage()
        defer { cleanup() }

        #expect(sut.optionalTheme == nil)

        sut.optionalTheme = .dark
        #expect(sut.optionalTheme == .dark)

        sut.optionalTheme = nil
        #expect(sut.optionalTheme == nil)
    }

    @Test
    func `Optional Int-based enum starts nil, can be set and cleared`() {
        let (sut, cleanup) = makeTestStorage()
        defer { cleanup() }

        #expect(sut.optionalPriority == nil)

        sut.optionalPriority = .high
        #expect(sut.optionalPriority == .high)

        sut.optionalPriority = nil
        #expect(sut.optionalPriority == nil)
    }
    
    @Test
    func `Enum values persist across instances`() {
        let (userDefaults, cleanup) = makeUserDefaults(suiteName: "test.enum.theme.priority.persistence")
        defer { cleanup() }
        
        let storage1 = TestStorage(userDefaults: userDefaults)
        storage1.theme = .dark
        storage1.priority = .high
        
        let storage2 = TestStorage(userDefaults: userDefaults)
        #expect(storage2.theme == .dark)
        #expect(storage2.priority == .high)
    }
}
