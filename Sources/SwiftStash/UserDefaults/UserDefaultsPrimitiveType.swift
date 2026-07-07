//
//  UserDefaultsPrimitiveType.swift
//  SwiftStash
//
// Copyright (c) 2026 SwiftStash contributors
// SPDX-License-Identifier: MIT
//

import Foundation

/// A marker protocol identifying types that UserDefaults can store natively as property list values.
///
/// SwiftStash uses this protocol to distinguish between types that can be written directly
/// to UserDefaults (via `set(_:forKey:)`) and types that require encoding — such as
/// `Codable` or `RawRepresentable` values. Without this distinction, initialiser overloads
/// on `@Stash` and `@Stashed` would be ambiguous for types like `String`-backed enums
/// that conform to both `RawRepresentable` and the primitive set.
///
/// ## Default Conformances
///
/// The following types conform out of the box:
/// `String`, `Int`, `Double`, `Float`, `Bool`, `Data`, `Date`, `URL`,
/// `Array` (where `Element: PropertyListNativeType`),
/// `Dictionary` (where `Key == String, Value: PropertyListNativeType`),
/// and `Optional` wrappers of any of the above.
///
/// Collections constrain their elements to ``PropertyListNativeType`` — a refinement
/// that excludes `URL` and `Optional` — because UserDefaults rejects those inside
/// collections at runtime. `[URL]` or `[String?]` are therefore compile errors;
/// use `@Stash(codable:)` for such values.
///
/// ## Do Not Add Custom Conformances
///
/// This protocol is public only because it appears in public initialiser constraints. Treat its
/// conformances as library-owned. Adding it to a custom type bypasses SwiftStash's compile-time
/// property-list validation and can cause `UserDefaults` to raise an Objective-C exception.
/// Store custom values with `@Stash(codable:defaultValue:)` instead.
///
/// The protocol refines `Sendable`: every property list type is a value type, and this
/// allows `@Stash` and `RawRepresentable` storage to remain `Sendable` without extra constraints.
public protocol UserDefaultsPrimitiveType: Sendable {}

/// A marker protocol for types UserDefaults stores natively **inside collections**.
///
/// This refines ``UserDefaultsPrimitiveType`` and exists for one reason: `URL` and
/// `Optional` are storable at the top level (SwiftStash archives URLs the way
/// `@AppStorage` does, and a top-level `nil` removes the key), but they are **not**
/// property-list types — an array or dictionary containing them is rejected by
/// UserDefaults at runtime. Requiring collection elements to be
/// `PropertyListNativeType` turns `[URL]`, `[String: URL]`, and `[String?]` into
/// compile errors instead of runtime crashes. Use `@Stash(codable:)` for those.
///
/// Conforming types: `String`, `Int`, `Double`, `Float`, `Bool`, `Data`, `Date`,
/// plus `Array` / `[String: _]` `Dictionary` where the elements are themselves
/// property-list native.
public protocol PropertyListNativeType: UserDefaultsPrimitiveType {}

extension String: PropertyListNativeType {}
extension Int: PropertyListNativeType {}
extension Double: PropertyListNativeType {}
extension Float: PropertyListNativeType {}
extension Bool: PropertyListNativeType {}
extension Data: PropertyListNativeType {}
extension Date: PropertyListNativeType {}

// URL is storable at the top level only (via the dedicated archiving setter);
// it is not a property-list type, so it must not appear inside collections.
extension URL: UserDefaultsPrimitiveType {}

extension Array: UserDefaultsPrimitiveType where Element: PropertyListNativeType {}
extension Array: PropertyListNativeType where Element: PropertyListNativeType {}
extension Dictionary: UserDefaultsPrimitiveType where Key == String, Value: PropertyListNativeType {}
extension Dictionary: PropertyListNativeType where Key == String, Value: PropertyListNativeType {}

// Optionals are supported at the top level (nil removes the key) but are not
// property-list values, so they must not appear inside collections either.
extension Optional: UserDefaultsPrimitiveType where Wrapped: UserDefaultsPrimitiveType {}
