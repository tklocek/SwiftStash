//
//  TestStorage.swift
//  SwiftStash
//
// Copyright (c) 2026 SwiftStash contributors
// SPDX-License-Identifier: MIT
//

import Foundation
@testable import SwiftStash

// MARK: - Standard Test Storage

/// Standard test storage with various property types for comprehensive testing
final class TestStorage: @unchecked Sendable {
    static let userProfileKey: String = "testUserProfile"
    static let optionalUserProfileKey: String = "testOptionalUserProfile"
    static let userProfileDefaultValue = UserProfile(name: "Default User", age: 0, email: "default@example.com")

    @Stash var stringValue: String
    @Stash var anotherStringValue: String
    @Stash var intValue: Int
    @Stash var boolValue: Bool
    @Stash var stringArrayValue: [String]
    @Stash var dictionaryValue: [String: String]
    @Stash var optionalStringValue: String?
    @Stash var userProfile: UserProfile
    @Stash var optionalUserProfile: UserProfile?
    @Stash var theme: Theme
    @Stash var optionalTheme: Theme?
    @Stash var priority: Priority
    @Stash var optionalPriority: Priority?

    init(userDefaults: UserDefaults) {
        _stringValue = Stash(key: "testString", defaultValue: "default", userDefaults: userDefaults)
        _anotherStringValue = Stash(key: "testAnotherString", defaultValue: "", userDefaults: userDefaults)
        _intValue = Stash(key: "testInt", defaultValue: 0, userDefaults: userDefaults)
        _boolValue = Stash(key: "testBool", defaultValue: false, userDefaults: userDefaults)
        _stringArrayValue = Stash(key: "testStringArray", defaultValue: [], userDefaults: userDefaults)
        _dictionaryValue = Stash(key: "testDictionary", defaultValue: [:], userDefaults: userDefaults)
        _optionalStringValue = Stash(key: "testOptionalString", userDefaults: userDefaults)
        _userProfile = Stash(
            codable: Self.userProfileKey,
            defaultValue: Self.userProfileDefaultValue,
            userDefaults: userDefaults
        )
        _optionalUserProfile = Stash(
            codable: Self.optionalUserProfileKey,
            userDefaults: userDefaults
        )
        _theme = Stash(key: "testTheme", defaultValue: .system, userDefaults: userDefaults)
        _optionalTheme = Stash(key: "testOptionalTheme", userDefaults: userDefaults)
        _priority = Stash(key: "testPriority", defaultValue: .medium, userDefaults: userDefaults)
        _optionalPriority = Stash(key: "testOptionalPriority", userDefaults: userDefaults)
    }
}

// MARK: - Failing Encodable Storage

/// Storage class for testing encoding failure scenarios
final class FailingEncodableStorage {
    static let failingValueKey = "failingValueKey"

    @Stash var failingValue: FailingEncodable

    init(userDefaults: UserDefaults) {
        _failingValue = Stash(
            codable: Self.failingValueKey,
            defaultValue: FailingEncodable(),
            userDefaults: userDefaults
        )
    }
}
