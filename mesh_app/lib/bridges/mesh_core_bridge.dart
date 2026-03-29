// Flutter Rust Bridge - Main Bridge Implementation
// Connects Dart/Flutter with Rust mesh_core library

import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge.dart';
import 'bridge_definitions.dart';

part 'mesh_core_bridge.frb.dart';

/// Initialize the Rust library and create the bridge
Future<void> initMeshCoreBridge() async {
  try {
    await RustLib.init();
    debugPrint('✓ MeshCore Rust bridge initialized successfully');
  } catch (e) {
    debugPrint('✗ Failed to initialize MeshCore bridge: $e');
    rethrow;
  }
}

/// Mesh Core API - High-level interface to Rust functions
class MeshCoreApi {
  static final MeshCoreApi _instance = MeshCoreApi._internal();
  factory MeshCoreApi() => _instance;
  MeshCoreApi._internal();

  /// Generate a new cryptographic identity
  Future<Identity> generateIdentity() async {
    try {
      return await generateIdentityHandler();
    } catch (e) {
      debugPrint('Error generating identity: $e');
      rethrow;
    }
  }

  /// Store identity in secure memory
  Future<bool> storeIdentity(Identity identity) async {
    try {
      return await storeIdentityHandler(identity: identity);
    } catch (e) {
      debugPrint('Error storing identity: $e');
      return false;
    }
  }

  /// Get current stored identity
  Future<Identity?> getCurrentIdentity() async {
    try {
      return await getCurrentIdentityHandler();
    } catch (e) {
      debugPrint('Error getting current identity: $e');
      return null;
    }
  }

  /// Encrypt a message for a recipient
  Future<EncryptedPayload> encryptMessage({
    required String messageContent,
    required String recipientPublicKey,
  }) async {
    try {
      return await encryptMessageHandler(
        messageContent: messageContent,
        recipientPublicKey: recipientPublicKey,
      );
    } catch (e) {
      debugPrint('Error encrypting message: $e');
      rethrow;
    }
  }

  /// Decrypt a received message
  Future<String> decryptMessage({
    required EncryptedPayload encryptedPayload,
    required String senderPublicKey,
  }) async {
    try {
      return await decryptMessageHandler(
        encryptedPayload: encryptedPayload,
        senderPublicKey: senderPublicKey,
      );
    } catch (e) {
      debugPrint('Error decrypting message: $e');
      rethrow;
    }
  }

  /// Create a new Automerge sync document
  Future<Uint8List> createSyncDocument() async {
    try {
      return await createSyncDocumentHandler();
    } catch (e) {
      debugPrint('Error creating sync document: $e');
      rethrow;
    }
  }

  /// Apply sync changes from another device
  Future<Uint8List?> applySyncChanges({
    required Uint8List document,
    required Uint8List changes,
  }) async {
    try {
      return await applySyncChangesHandler(
        document: document,
        changes: changes,
      );
    } catch (e) {
      debugPrint('Error applying sync changes: $e');
      return null;
    }
  }
}
