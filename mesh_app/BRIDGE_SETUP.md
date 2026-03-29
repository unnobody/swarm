# Flutter Rust Bridge Integration Guide

## Overview
This project uses `flutter_rust_bridge` to connect the Flutter/Dart UI with the Rust `mesh_core` library for cryptographic operations and data synchronization.

## Architecture

```
┌─────────────────┐         ┌──────────────────┐
│   Flutter UI    │◄───────►│   Dart Services  │
│   (mesh_app)    │         │                  │
└─────────────────┘         └────────┬─────────┘
                                     │
                            ┌────────▼─────────┐
                            │  FFI Bridge      │
                            │  (flutter_rust_  │
                            │   bridge)        │
                            └────────┬─────────┘
                                     │
                            ┌────────▼─────────┐
                            │   Rust Core      │
                            │   (mesh_core)    │
                            │  - Crypto        │
                            │  - Automerge     │
                            │  - libp2p        │
                            └──────────────────┘
```

## Setup Instructions

### 1. Install flutter_rust_bridge_codegen

```bash
cargo install flutter_rust_bridge_codegen
```

### 2. Generate Bridge Code

After modifying `mesh_core/src/lib.rs`, run:

```bash
cd mesh_app
flutter_rust_bridge_codegen \
  --rust-input ../mesh_core/src/lib.rs \
  --dart-output lib/bridges/mesh_core_bridge.dart \
  --c-output ios/Runner/mesh_core.h
```

This will generate:
- `lib/bridges/mesh_core_bridge.frb.dart` - Dart FFI bindings
- `ios/Runner/mesh_core.h` - C header for iOS
- `android/app/src/main/jni/` - Android JNI bindings

### 3. Build Rust Library

#### For Android:
```bash
cd ../mesh_core
cargo build --release --target aarch64-linux-android
cargo build --release --target x86_64-linux-android
```

Copy the `.so` files to:
- `mesh_app/android/app/src/main/jniLibs/arm64-v8a/libmesh_core.so`
- `mesh_app/android/app/src/main/jniLibs/x86_64/libmesh_core.so`

#### For iOS:
```bash
cd ../mesh_core
cargo build --release --target aarch64-apple-ios
cargo build --release --target x86_64-apple-darwin # for simulator
```

### 4. Run the App

```bash
cd mesh_app
flutter run
```

## API Reference

### Rust Functions (mesh_core/src/lib.rs)

| Function | Description | Returns |
|----------|-------------|---------|
| `generate_identity()` | Create new cryptographic identity | `Identity` |
| `store_identity(identity)` | Store identity in secure memory | `bool` |
| `get_current_identity()` | Retrieve stored identity | `Option<Identity>` |
| `encrypt_message(content, recipient_pk)` | Encrypt message for recipient | `Result<EncryptedPayload>` |
| `decrypt_message(payload, sender_pk)` | Decrypt received message | `Result<String>` |
| `create_sync_document()` | Create Automerge document | `Vec<u8>` |
| `apply_sync_changes(doc, changes)` | Apply CRDT sync changes | `Result<Vec<u8>>` |

### Dart API (MeshCoreApi)

```dart
import 'package:mesh_secure/bridges/mesh_core_bridge.dart';

final api = MeshCoreApi();

// Generate identity
final identity = await api.generateIdentity();

// Store identity
await api.storeIdentity(identity);

// Encrypt message
final payload = await api.encryptMessage(
  messageContent: 'Hello!',
  recipientPublicKey: recipientPk,
);

// Decrypt message
final content = await api.decryptMessage(
  encryptedPayload: payload,
  senderPublicKey: senderPk,
);
```

## Data Structures

### Identity
```dart
class Identity {
  final String publicKey;
  final String secretKey;
  final int createdAt;
}
```

### Message
```dart
class Message {
  final String id;
  final String senderId;
  final String content;
  final int timestamp;
  final bool encrypted;
}
```

### EncryptedPayload
```dart
class EncryptedPayload {
  final Uint8List ciphertext;
  final Uint8List nonce;
}
```

## Security Considerations

1. **Key Storage**: In production, store secret keys in:
   - iOS: Secure Enclave via Keychain
   - Android: Hardware-backed Keystore

2. **Memory Safety**: Rust ensures memory safety for cryptographic operations

3. **Encryption**: Uses libsodium's `crypto_box` (Curve25519 + XSalsa20 + Poly1305)

4. **Forward Secrecy**: Future implementation will add Double Ratchet protocol

## Troubleshooting

### Bridge Initialization Failed
- Ensure Rust library is built for your target platform
- Check that library files are in correct locations
- Verify `pubspec.yaml` includes `flutter_rust_bridge` dependency

### Type Mismatch Errors
- Run `flutter_rust_bridge_codegen` after any Rust struct changes
- Ensure Dart definitions match Rust structs

### Performance Issues
- Use `#[frb(sync)]` only for fast operations (<16ms)
- For heavy operations, use async FFI (remove `sync` attribute)
- Consider using Isolate for CPU-intensive tasks

## Next Steps

1. ✅ Complete FFI Bridge setup
2. ⏳ Implement transport layer (Android Nearby / iOS Multipeer)
3. ⏳ Add Automerge sync for offline-first messaging
4. ⏳ Implement full libp2p for internet transport
5. ⏳ Add QR code contact exchange
6. ⏳ Build network status visualization UI

## Resources

- [flutter_rust_bridge Documentation](https://fzyzcjy.github.io/flutter_rust_bridge/)
- [libsodium Documentation](https://doc.libsodium.org/)
- [Automerge Documentation](https://automerge.org/)
- [libp2p Documentation](https://docs.libp2p.io/)
