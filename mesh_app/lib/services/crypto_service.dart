import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import '../bridges/mesh_core_bridge.dart';
import '../bridges/bridge_definitions.dart';
import '../models/message_model.dart';
import '../models/peer_model.dart';

/// Service for handling message encryption and decryption
class CryptoService extends ChangeNotifier {
  final MeshCoreApi _meshCoreApi = MeshCoreApi();
  
  bool _isInitialized = false;
  bool _isProcessing = false;

  bool get isInitialized => _isInitialized;
  bool get isProcessing => _isProcessing;

  /// Initialize crypto service
  Future<void> initialize() async {
    try {
      // Bridge is already initialized in main.dart
      _isInitialized = true;
      notifyListeners();
      debugPrint('✓ CryptoService initialized');
    } catch (e) {
      debugPrint('✗ Failed to initialize CryptoService: $e');
      rethrow;
    }
  }

  /// Encrypt a message for a specific recipient
  Future<EncryptedPayload> encryptMessage({
    required String messageContent,
    required String recipientPublicKey,
  }) async {
    if (!_isInitialized) {
      throw StateError('CryptoService not initialized');
    }

    _isProcessing = true;
    notifyListeners();

    try {
      final payload = await _meshCoreApi.encryptMessage(
        messageContent: messageContent,
        recipientPublicKey: recipientPublicKey,
      );

      debugPrint('✓ Message encrypted successfully');
      return payload;
    } catch (e) {
      debugPrint('✗ Error encrypting message: $e');
      rethrow;
    } finally {
      _isProcessing = false;
      notifyListeners();
    }
  }

  /// Decrypt a received message
  Future<String> decryptMessage({
    required EncryptedPayload encryptedPayload,
    required String senderPublicKey,
  }) async {
    if (!_isInitialized) {
      throw StateError('CryptoService not initialized');
    }

    _isProcessing = true;
    notifyListeners();

    try {
      final decrypted = await _meshCoreApi.decryptMessage(
        encryptedPayload: encryptedPayload,
        senderPublicKey: senderPublicKey,
      );

      debugPrint('✓ Message decrypted successfully');
      return decrypted;
    } catch (e) {
      debugPrint('✗ Error decrypting message: $e');
      rethrow;
    } finally {
      _isProcessing = false;
      notifyListeners();
    }
  }

  /// Encrypt and wrap message with metadata
  Future<Map<String, dynamic>> encryptAndWrap({
    required String content,
    required Peer recipient,
    required String senderId,
  }) async {
    final payload = await encryptMessage(
      messageContent: content,
      recipientPublicKey: recipient.publicKey,
    );

    return {
      'id': '${senderId}_${DateTime.now().millisecondsSinceEpoch}',
      'sender_id': senderId,
      'recipient_id': recipient.id,
      'content_encrypted': true,
      'ciphertext': payload.ciphertext,
      'nonce': payload.nonce,
      'timestamp': DateTime.now().millisecondsSinceEpoch ~/ 1000,
    };
  }

  /// Unwrap and decrypt message
  Future<MessageModel> unwrapAndDecrypt({
    required Map<String, dynamic> wrappedMessage,
    required Peer sender,
  }) async {
    final payload = EncryptedPayload(
      ciphertext: Uint8List.fromList(
        (wrappedMessage['ciphertext'] as List).cast<int>(),
      ),
      nonce: Uint8List.fromList(
        (wrappedMessage['nonce'] as List).cast<int>(),
      ),
    );

    final content = await decryptMessage(
      encryptedPayload: payload,
      senderPublicKey: sender.publicKey,
    );

    return MessageModel(
      id: wrappedMessage['id'] as String,
      senderId: sender.id,
      content: content,
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        (wrappedMessage['timestamp'] as int) * 1000,
      ),
      isEncrypted: true,
      status: MessageStatus.received,
    );
  }
}
