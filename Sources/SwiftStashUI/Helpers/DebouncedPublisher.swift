//
//  DebouncedPublisher.swift
//  SwiftStash
//
// Copyright (c) 2026 SwiftStash contributors
// SPDX-License-Identifier: MIT
//

import Foundation
import Combine

extension Publisher where Failure == Never {
    func debounceForStash() -> AnyPublisher<Output, Never> {
        self.debounce(
            for: .milliseconds(10),
            scheduler: RunLoop.main
        )
        .eraseToAnyPublisher()
    }
}
