# API Reference

@Metadata {
    @PageImage(purpose: card, source: "card-api-reference", alt: "API Reference")
}

Complete symbol reference for the ``SwiftStash`` module: property wrappers, type-safety
markers, configuration, Keychain types, and the biometrics/Secure Enclave surface.

## Topics

### Property Wrappers

- ``Stash``
- ``SecureStash``
- ``StashHandle``
- ``SecureStashHandle``

### Type Safety

- ``UserDefaultsPrimitiveType``
- ``PropertyListNativeType``

### Configuration

- ``SwiftStash``
- ``SwiftStash/logLevel``
- ``SwiftStash/configureLogging(level:)``
- ``SwiftStash/configureUserDefaults(_:)``
- ``SwiftStash/configureUserDefaults(suiteName:)``
- ``SwiftStash/configureUserDefaults(_:for:)``
- ``SwiftStash/userDefaults``
- ``SwiftStash/userDefaults(for:)``
- ``SwiftStash/resetUserDefaults()``
- ``SwiftStash/resetUserDefaults(for:)``
- ``SwiftStash/configureKeychain(service:accessibility:isSynchronizable:itemClass:)``
- ``StashLogLevel``

### Store Scopes

- ``StashScope``
- ``StashScopedKey``

### Keychain

- ``KeychainManager``
- ``KeychainManagerProtocol``
- ``KeychainAccessibility``
- ``KeychainItemClass``
- ``KeychainError``
- ``SecureStashHelpers``

### Biometrics & Secure Enclave

- ``KeychainCryptoManagerProtocol``
- ``CryptoKeyDescriptor``
- ``CryptoKeyAlgorithm``
- ``CryptoKeyStorage``
- ``SecAccessControlFlags``
