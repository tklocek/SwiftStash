//
//  StashLogLevel.swift
//  SwiftStash
//
// Copyright (c) 2026 SwiftStash contributors
// SPDX-License-Identifier: MIT
//

import OSLog

/// Defines the logging verbosity levels for SwiftStash operations.
///
/// StashLogLevel controls which log messages are emitted during runtime:
/// - `.minimal`: Only critical errors are logged
/// - `.normal`: Errors and important operations are logged
/// - `.verbose`: All operations including detailed encoding/decoding information
///
/// This enum can be shared across different logging implementations and wrappers.
public enum StashLogLevel: Int, Sendable, CaseIterable, Hashable, Codable {
    /// Minimal logging - only critical errors
    case minimal = 0
    
    /// Normal logging - errors and important operations (default)
    case normal = 1
    
    /// Verbose logging - all operations with detailed information
    case verbose = 2
    
    /// Converts StashLogLevel to OSLogType for use with os.Logger
    var osLogType: OSLogType {
        switch self {
        case .minimal:
            return .error
        case .normal:
            return .default
        case .verbose:
            return .debug
        }
    }
    
    /// Determines if a message at the given level should be logged
    /// - Parameter messageLevel: The level of the message being considered
    /// - Returns: true if the message should be logged, false otherwise
    func shouldLog(messageLevel: StashLogLevel) -> Bool {
        messageLevel.rawValue <= self.rawValue
    }
}

extension StashLogLevel: CustomStringConvertible {
    public var description: String {
        switch self {
            case .minimal: return "Minimal"
            case .normal: return "Normal"
            case .verbose: return "Verbose"
        }
    }
}
