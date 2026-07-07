//
//  OptionalProtocol.swift
//  SwiftStash
//
// Copyright (c) 2026 SwiftStash contributors
// SPDX-License-Identifier: MIT
//

import Foundation

/// Internal protocol for detecting nil values in generic contexts.
internal protocol OptionalProtocol {
    var isNil: Bool { get }
}

extension Optional: OptionalProtocol {
    var isNil: Bool { self == nil }
}
