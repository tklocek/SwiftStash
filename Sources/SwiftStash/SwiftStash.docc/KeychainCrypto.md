# Biometrics & Secure Enclave

@Metadata {
    @PageImage(purpose: card, source: "card-keychain-crypto", alt: "Biometrics & Secure Enclave")
}

Protect keychain items with Face ID / Touch ID and generate hardware-backed cryptographic keys.

## Overview

Beyond plain CRUD, ``KeychainManager`` exposes the access-control layer of the
Security framework: items gated by user presence (`kSecAttrAccessControl`) and
asymmetric key pairs whose private half can live inside the Secure Enclave.

Two rules shape the whole API:

- **Authentication is caller-owned.** Methods accept an optional, already-evaluated
  `LAContext` and never present prompts of their own. You decide when and how the
  user authenticates; the package reuses that confirmation.
- **Typed errors everywhere.** Every operation throws ``KeychainError``, matching
  the rest of ``KeychainManager``.

> Note: These APIs require the LocalAuthentication framework and are unavailable on tvOS.
> Calling them from tvOS code is a compile-time error with an explanatory message
> (`@available(*, unavailable)` stubs), not a silently missing symbol.

## Biometric-Protected Items

Writing uses the **delete-then-add** pattern — `SecItemUpdate` on an
access-control item would force a biometric re-prompt, so the API simply doesn't
offer it:

```swift
let keychain = KeychainManager(service: Bundle.main.bundleIdentifier!)

try keychain.saveBiometric(
    Data("secret".utf8),
    for: "authToken",
    with: .genericPassword,
    accessibility: .whenUnlockedThisDeviceOnly,
    flags: [.userPresence]
)
```

Reading requires a satisfied `LAContext` so the item decrypts without prompting again:

```swift
let context = LAContext()
try await context.evaluatePolicy(
    .deviceOwnerAuthenticationWithBiometrics,
    localizedReason: "Unlock your token"
)

let secret = try keychain.loadBiometric(
    for: "authToken",
    with: .genericPassword,
    authenticationContext: context
)
```

Biometric items are never iCloud-synced; `kSecAttrSynchronizable` is forced to `false`.

## Existence Checks Without Prompts

`SecItemCopyMatching` on a biometric item would normally surface Face ID even
when you only ask "is it there?". ``KeychainManager/exists(for:with:authenticationContext:)``
probes with `LAContext.interactionNotAllowed`, treating `errSecInteractionNotAllowed`
as "exists":

```swift
if keychain.exists(for: "authToken", with: .genericPassword) {
    // item present — no prompt was shown
}
```

## Cryptographic Keys

Keys are identified by a ``CryptoKeyDescriptor`` (application tag + optional
``CryptoKeyAlgorithm``) and stored per ``CryptoKeyStorage``:

```swift
let descriptor = CryptoKeyDescriptor(
    stringTag: "com.example.signing.user42",
    algorithm: .ec
)

// Private key generated inside the Secure Enclave — material never leaves the hardware
let publicKey = try keychain.generateKey(
    descriptor: descriptor,
    keySizeInBits: 256,
    storage: .secureEnclave(
        accessibility: .whenUnlockedThisDeviceOnly,
        flags: [.privateKeyUsage]
    )
)
```

Later, load the private-key reference for `SecKeyCreateSignature` and friends:

```swift
let privateKey = try keychain.loadKeyReference(descriptor)
```

Loading a reference does not authenticate by itself — user-presence flags are
enforced when the key is *used*. Pass a satisfied `LAContext` to reuse an existing
confirmation.

Probing and deletion work without knowing the algorithm:

```swift
let probe = CryptoKeyDescriptor(stringTag: "com.example.signing.user42")
if keychain.existsKey(probe) {
    try keychain.deleteKey(probe)   // idempotent
}
```

### Secure Enclave Constraints

- Only **EC P-256** keys are supported; requesting `.rsa` with
  ``CryptoKeyStorage/secureEnclave(accessibility:flags:)`` throws
  ``KeychainError/secureEnclaveAlgorithmInvalid``.
- ``KeychainManager/generateKey(descriptor:keySizeInBits:storage:authenticationContext:)``
  **replaces** any existing key under the same tag, regardless of algorithm.
- The Secure Enclave requires real hardware — the simulator falls back with
  ``KeychainError/keyGenerationFailed(_:)``.

## Mocking

The crypto surface is defined by ``KeychainCryptoManagerProtocol`` — a protocol
separate from ``KeychainManagerProtocol``, so existing CRUD mocks are not forced
to implement crypto methods. ``KeychainManager`` conforms to both.

## See Also

- ``KeychainCryptoManagerProtocol``
- ``CryptoKeyDescriptor``
- ``CryptoKeyStorage``
- ``SecAccessControlFlags``
- <doc:KeychainStorage>
- <doc:KeychainConfiguration>
