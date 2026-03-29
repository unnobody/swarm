# Secure Mesh Messenger - Build Instructions

## Project Structure

```
/workspace
├── mesh_app/              # Flutter application
│   ├── lib/
│   │   ├── bridges/       # Flutter Rust Bridge integration
│   │   ├── services/      # Business logic services
│   │   ├── screens/       # UI screens
│   │   └── main.dart      # App entry point
│   └── pubspec.yaml
│
├── mesh_core/             # Rust core library
│   ├── src/
│   │   └── lib.rs         # Crypto, sync, network functions
│   └── Cargo.toml
│
└── BUILD_INSTRUCTIONS.md
```

## Prerequisites

1. **Flutter SDK** (3.0+)
   ```bash
   flutter doctor
   ```

2. **Rust Toolchain**
   ```bash
   curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
   rustup default stable
   ```

3. **flutter_rust_bridge_codegen**
   ```bash
   cargo install flutter_rust_bridge_codegen
   ```

4. **Android NDK** (for Android builds)
   ```bash
   # Install via Android Studio or sdkmanager
   sdkmanager "ndk;25.2.9519653"
   ```

5. **Xcode** (for iOS builds, macOS only)
   ```bash
   xcode-select --install
   ```

## Step 1: Generate Bridge Code

```bash
cd /workspace/mesh_app
flutter_rust_bridge_codegen \
  --rust-input ../mesh_core/src/lib.rs \
  --dart-output lib/bridges/mesh_core_bridge.dart \
  --c-output ios/Runner/mesh_core.h
```

This generates:
- `lib/bridges/mesh_core_bridge.frb.dart` - Dart FFI bindings
- `ios/Runner/mesh_core.h` - C header for iOS
- Android JNI bindings

## Step 2: Build Rust Library

### For Android

```bash
cd /workspace/mesh_core

# ARM64 (most Android devices)
rustup target add aarch64-linux-android
cargo build --release --target aarch64-linux-android

# x86_64 (emulators)
rustup target add x86_64-linux-android
cargo build --release --target x86_64-linux-android
```

Copy libraries to Android project:
```bash
mkdir -p ../mesh_app/android/app/src/main/jniLibs/arm64-v8a
mkdir -p ../mesh_app/android/app/src/main/jniLibs/x86_64

cp target/aarch64-linux-android/release/libmesh_core.so \
   ../mesh_app/android/app/src/main/jniLibs/arm64-v8a/

cp target/x86_64-linux-android/release/libmesh_core.so \
   ../mesh_app/android/app/src/main/jniLibs/x86_64/
```

### For iOS

```bash
cd /workspace/mesh_core

# ARM64 (real devices)
rustup target add aarch64-apple-ios
cargo build --release --target aarch64-apple-ios

# x86_64 (simulator)
rustup target add x86_64-apple-darwin
cargo build --release --target x86_64-apple-darwin
```

Create a universal library for iOS:
```bash
mkdir -p ../mesh_app/ios/Frameworks
lipo -create \
  target/aarch64-apple-ios/release/libmesh_core.a \
  target/x86_64-apple-darwin/release/libmesh_core.a \
  -output ../mesh_app/ios/Frameworks/libmesh_core.a
```

## Step 3: Install Flutter Dependencies

```bash
cd /workspace/mesh_app
flutter pub get
```

## Step 4: Run the Application

### On Android Emulator/Device
```bash
cd /workspace/mesh_app
flutter run
```

### On iOS Simulator/Device (macOS only)
```bash
cd /workspace/mesh_app
flutter run -d ios
```

### On Desktop (for testing)
```bash
cd /workspace/mesh_app
flutter run -d linux   # or -d macos, -d windows
```

## Testing the Integration

1. **Launch the app** - You should see the onboarding screen
2. **Create identity** - Tap "Get Started" to generate cryptographic keys
3. **Check logs**:
   ```bash
   flutter logs | grep -i "identity\|mesh"
   ```

Expected output:
```
✓ Identity created and stored successfully
  Public Key: dGhpcyBpcyBhIG1v...
```

## Troubleshooting

### "Failed to initialize cryptography"
- Ensure libsodium is available (included in sodiumoxide crate)
- Check that Rust library is built correctly

### "Bridge not initialized"
- Verify `flutter_rust_bridge_codegen` was run
- Check that generated files exist in `lib/bridges/`

### Android build fails
- Ensure NDK is installed and ANDROID_NDK_HOME is set
- Check that `.so` files are in correct `jniLibs` directories

### iOS build fails
- Ensure Xcode command line tools are installed
- Check that `.a` library is in `ios/Frameworks/`
- Verify signing certificates for device deployment

## Next Development Steps

1. ✅ **FFI Bridge** - Complete (this document)
2. ⏳ **Transport Layer** - Implement Android Nearby API / iOS Multipeer Connectivity
3. ⏳ **Automerge Sync** - Full CRDT implementation for message synchronization
4. ⏳ **libp2p Integration** - Internet-based peer discovery and messaging
5. ⏳ **UI Polish** - Network status indicators, contact management
6. ⏳ **Security Hardening** - Secure Enclave/Keystore integration

## Architecture Overview

```
┌─────────────────────────────────────────────────────┐
│                  Flutter UI Layer                    │
│  (Screens, Widgets, State Management with Provider) │
└────────────────────┬────────────────────────────────┘
                     │
┌────────────────────▼────────────────────────────────┐
│               Dart Service Layer                     │
│  (IdentityService, CryptoService, MeshCoreApi)      │
└────────────────────┬────────────────────────────────┘
                     │
┌────────────────────▼────────────────────────────────┐
│            Flutter Rust Bridge (FFI)                 │
│         (Auto-generated bindings & marshaling)       │
└────────────────────┬────────────────────────────────┘
                     │
┌────────────────────▼────────────────────────────────┐
│                  Rust Core Layer                     │
│  ┌──────────────┐  ┌──────────────┐  ┌───────────┐ │
│  │  libsodium   │  │   Automerge  │  │   libp2p  │ │
│  │  (Crypto)    │  │   (CRDT)     │  │ (Network) │ │
│  └──────────────┘  └──────────────┘  └───────────┘ │
└─────────────────────────────────────────────────────┘
```

## Resources

- [Flutter Documentation](https://docs.flutter.dev/)
- [Rust Documentation](https://doc.rust-lang.org/book/)
- [flutter_rust_bridge Guide](https://fzyzcjy.github.io/flutter_rust_bridge/)
- [libsodium Cryptography](https://doc.libsodium.org/)
- [Automerge CRDT](https://automerge.org/)
