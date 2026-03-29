// Flutter Rust Bridge - Dart Definitions
// Auto-generated definitions for mesh_core Rust library

import 'dart:typed_data';

/// Identity with cryptographic keypair
class Identity {
  final String publicKey;
  final String secretKey;
  final int createdAt;

  Identity({
    required this.publicKey,
    required this.secretKey,
    required this.createdAt,
  });

  factory Identity.fromMap(Map<String, dynamic> map) {
    return Identity(
      publicKey: map['public_key'] as String,
      secretKey: map['secret_key'] as String,
      createdAt: map['created_at'] as int,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'public_key': publicKey,
      'secret_key': secretKey,
      'created_at': createdAt,
    };
  }

  @override
  String toString() => 'Identity(publicKey: $publicKey, createdAt: $createdAt)';
}

/// Message structure for mesh communication
class Message {
  final String id;
  final String senderId;
  final String content;
  final int timestamp;
  final bool encrypted;

  Message({
    required this.id,
    required this.senderId,
    required this.content,
    required this.timestamp,
    required this.encrypted,
  });

  factory Message.fromMap(Map<String, dynamic> map) {
    return Message(
      id: map['id'] as String,
      senderId: map['sender_id'] as String,
      content: map['content'] as String,
      timestamp: map['timestamp'] as int,
      encrypted: map['encrypted'] as bool,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'sender_id': senderId,
      'content': content,
      'timestamp': timestamp,
      'encrypted': encrypted,
    };
  }
}

/// Encrypted message payload
class EncryptedPayload {
  final Uint8List ciphertext;
  final Uint8List nonce;

  EncryptedPayload({
    required this.ciphertext,
    required this.nonce,
  });

  factory EncryptedPayload.fromMap(Map<String, dynamic> map) {
    return EncryptedPayload(
      ciphertext: Uint8List.fromList(map['ciphertext'] as List<int>),
      nonce: Uint8List.fromList(map['nonce'] as List<int>),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'ciphertext': ciphertext.toList(),
      'nonce': nonce.toList(),
    };
  }
}
