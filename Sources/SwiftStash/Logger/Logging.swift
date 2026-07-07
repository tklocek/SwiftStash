//
//  Logging.swift
//  SwiftStash
//
// Copyright (c) 2026 SwiftStash contributors
// SPDX-License-Identifier: MIT
//


import OSLog
import Foundation

/// Defines the storage backend type for logging purposes.
///
/// Used to route log messages to appropriate OSLog categories.
package enum StorageType: Sendable, Equatable {
    case userDefaults
    case keychain
    // Future: case fileSystem, case cloudKit, etc.
}

/// A lightweight description of a log requested by a SwiftStash storage backend.
///
/// This is package-scoped so the test target can verify that each storage backend routes
/// messages to the correct OSLog category without exposing a logging hook as public API.
package struct LoggingEvent: Sendable, Equatable {
    package enum Kind: Sendable, Equatable {
        case error
        case operation
        case coding
    }

    package let kind: Kind
    package let storageType: StorageType
    package let key: String?
}

/// Logging class is responsible for managing logs to the native OSLog system.
///
/// Handles logging for all SwiftStash storage backends:
/// - UserDefaults (@Stash)
/// - Keychain (@SecureStash)
/// - Future: File system, CloudKit, etc.
///
/// The logging system supports three levels of verbosity:
/// - `.minimal`: Only critical errors are logged (default)
/// - `.normal`: Errors and important operations
/// - `.verbose`: All operations with detailed information
///
/// This is an internal implementation detail. Users should configure logging via ``SwiftStash/logLevel`` or ``SwiftStash/configureLogging(level:)``.
package final class Logging: @unchecked Sendable {
    typealias Logger = os.Logger
    
    private init() {}
    
    private static let subsystem: String = "SwiftStash"
    
    /// Current log level configuration. Default is `.minimal` (errors only).
    private static let lock = NSLock()
    private nonisolated(unsafe) static var _currentLogLevel: StashLogLevel = .minimal
    private nonisolated(unsafe) static var _eventObserver: (@Sendable (LoggingEvent) -> Void)?
    
    /// Configure the logging level for SwiftStash operations.
    /// - Parameter level: The desired log level (minimal, normal, or verbose)
    package static func configure(level: StashLogLevel) {
        lock.lock()
        defer { lock.unlock() }
        unsafe _currentLogLevel = level
    }

    /// Returns the current configured log level.
    package static var logLevel: StashLogLevel {
        lock.lock()
        defer { lock.unlock() }
        return unsafe _currentLogLevel
    }

    /// Installs a package-internal observer used by integration tests.
    /// Pass `nil` to remove it.
    package static func setEventObserver(_ observer: (@Sendable (LoggingEvent) -> Void)?) {
        lock.lock()
        defer { lock.unlock() }
        unsafe _eventObserver = observer
    }

    private static func record(_ event: LoggingEvent) {
        lock.lock()
        let observer = unsafe _eventObserver
        lock.unlock()
        observer?(event)
    }
    
    private enum Category: String {
        case storageOperations = "Storage.Operations"
        case storageErrors = "Storage.Errors"
        case storageCoding = "Storage.Coding"
        case keychainOperations = "Keychain.Operations"
        case keychainErrors = "Keychain.Errors"
        case keychainCoding = "Keychain.Coding"
        
        var logger: Logger {
            Logger(subsystem: Logging.subsystem, category: rawValue)
        }
        
        /// The required log level for this category
        var requiredLevel: StashLogLevel {
            switch self {
            case .storageErrors, .keychainErrors:
                return .minimal
            case .storageOperations, .keychainOperations:
                return .normal
            case .storageCoding, .keychainCoding:
                return .verbose
            }
        }
    }
        
    // MARK: - Logger Access
        
    /// Logs storage errors (requires minimal log level).
    /// Uses privacy-preserving logging for sensitive data.
    /// - Parameters:
    ///   - message: Error message
    ///   - key: Optional key being accessed
    ///   - type: Optional type name
    ///   - storageType: The storage backend type (defaults to `.userDefaults`)
    package static func logError(_ message: String, key: String? = nil, type: String? = nil, storageType: StorageType = .userDefaults) {
        let errorCategory: Category = switch storageType {
        case .userDefaults: .storageErrors
        case .keychain: .keychainErrors
        }
        record(LoggingEvent(kind: .error, storageType: storageType, key: key))
        guard logLevel.shouldLog(messageLevel: errorCategory.requiredLevel) else { return }
        
        if let key, let type {
            errorCategory.logger.error(
                "\(message, privacy: .public) [key: \(key, privacy: .private), type: \(type, privacy: .public)]"
            )
        } else {
            errorCategory.logger.error("\(message, privacy: .public)")
        }
    }
    
    /// Logs storage operations (requires normal log level).
    /// Uses privacy-preserving logging for keys.
    /// - Parameters:
    ///   - operation: Operation name (e.g., "GET", "SET", "DELETE")
    ///   - key: The key being accessed
    ///   - type: Optional type name
    ///   - itemClass: Optional item class (for keychain operations)
    ///   - storageType: The storage backend type (defaults to `.userDefaults`)
    package static func logOperation(_ operation: String, key: String, type: String? = nil, itemClass: String? = nil, storageType: StorageType = .userDefaults) {
        let operationCategory: Category = switch storageType {
        case .userDefaults: .storageOperations
        case .keychain: .keychainOperations
        }
        record(LoggingEvent(kind: .operation, storageType: storageType, key: key))
        guard logLevel.shouldLog(messageLevel: operationCategory.requiredLevel) else { return }
        
        if let type, let itemClass {
            operationCategory.logger.log(
                "\(operation, privacy: .public) [key: \(key, privacy: .private), type: \(type, privacy: .public), class: \(itemClass, privacy: .public)]"
            )
        } else if let type {
            operationCategory.logger.log(
                "\(operation, privacy: .public) [key: \(key, privacy: .private), type: \(type, privacy: .public)]"
            )
        } else if let itemClass {
            operationCategory.logger.log(
                "\(operation, privacy: .public) [key: \(key, privacy: .private), class: \(itemClass, privacy: .public)]"
            )
        } else {
            operationCategory.logger.log(
                "\(operation, privacy: .public) [key: \(key, privacy: .private)]"
            )
        }
    }
    
    /// Logs detailed coding operations (requires verbose log level).
    /// Uses privacy-preserving logging for keys and values.
    /// - Parameters:
    ///   - message: Coding message
    ///   - key: Key being encoded/decoded
    ///   - type: Type name
    ///   - storageType: The storage backend type (defaults to `.userDefaults`)
    package static func logCoding(_ message: String, key: String, type: String, storageType: StorageType = .userDefaults) {
        let codingCategory: Category = switch storageType {
        case .userDefaults: .storageCoding
        case .keychain: .keychainCoding
        }
        record(LoggingEvent(kind: .coding, storageType: storageType, key: key))
        guard logLevel.shouldLog(messageLevel: codingCategory.requiredLevel) else { return }
        
        codingCategory.logger.debug(
            "\(message, privacy: .public) [key: \(key, privacy: .private), type: \(type, privacy: .public)]"
        )
    }
}
