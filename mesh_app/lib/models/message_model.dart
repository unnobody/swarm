/// Message status in the mesh network
enum MessageStatus {
  /// Message is being composed
  drafting,
  
  /// Message is queued for sending (offline)
  pending,
  
  /// Message sent via direct connection
  sentDirect,
  
  /// Message sent via mesh relay
  sentRelayed,
  
  /// Message received and decrypted
  received,
  
  /// Message delivery confirmed
  delivered,
  
  /// Failed to send
  failed,
}

/// Connection type used for message transmission
enum ConnectionType {
  /// Direct Bluetooth Low Energy connection
  ble,
  
  /// Wi-Fi Direct or local network
  wifiDirect,
  
  /// Internet via libp2p
  internet,
  
  /// Multi-hop mesh relay
  meshRelay,
  
  /// Unknown or not yet determined
  unknown,
}

/// Message model for mesh communication
class MessageModel {
  final String id;
  final String senderId;
  final String? recipientId;
  final String content;
  final DateTime timestamp;
  final bool isEncrypted;
  final MessageStatus status;
  final ConnectionType? connectionType;
  final int? hopCount; // Number of relay hops (for mesh)
  final DateTime? deliveredAt;
  final DateTime? readAt;

  MessageModel({
    required this.id,
    required this.senderId,
    this.recipientId,
    required this.content,
    required this.timestamp,
    this.isEncrypted = true,
    this.status = MessageStatus.pending,
    this.connectionType,
    this.hopCount,
    this.deliveredAt,
    this.readAt,
  });

  /// Create a copy with updated fields
  MessageModel copyWith({
    String? id,
    String? senderId,
    String? recipientId,
    String? content,
    DateTime? timestamp,
    bool? isEncrypted,
    MessageStatus? status,
    ConnectionType? connectionType,
    int? hopCount,
    DateTime? deliveredAt,
    DateTime? readAt,
  }) {
    return MessageModel(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      recipientId: recipientId ?? this.recipientId,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      isEncrypted: isEncrypted ?? this.isEncrypted,
      status: status ?? this.status,
      connectionType: connectionType ?? this.connectionType,
      hopCount: hopCount ?? this.hopCount,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      readAt: readAt ?? this.readAt,
    );
  }

  /// Convert to map for serialization
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'sender_id': senderId,
      'recipient_id': recipientId,
      'content': content,
      'timestamp': timestamp.millisecondsSinceEpoch ~/ 1000,
      'is_encrypted': isEncrypted,
      'status': status.name,
      'connection_type': connectionType?.name,
      'hop_count': hopCount,
      'delivered_at': deliveredAt?.millisecondsSinceEpoch ~/ 1000,
      'read_at': readAt?.millisecondsSinceEpoch ~/ 1000,
    };
  }

  /// Create from map (deserialization)
  factory MessageModel.fromMap(Map<String, dynamic> map) {
    return MessageModel(
      id: map['id'] as String,
      senderId: map['sender_id'] as String,
      recipientId: map['recipient_id'] as String?,
      content: map['content'] as String,
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        (map['timestamp'] as int) * 1000,
      ),
      isEncrypted: map['is_encrypted'] as bool? ?? true,
      status: MessageStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => MessageStatus.pending,
      ),
      connectionType: map['connection_type'] != null
          ? ConnectionType.values.firstWhere(
              (e) => e.name == map['connection_type'],
              orElse: () => ConnectionType.unknown,
            )
          : null,
      hopCount: map['hop_count'] as int?,
      deliveredAt: map['delivered_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              (map['delivered_at'] as int) * 1000,
            )
          : null,
      readAt: map['read_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              (map['read_at'] as int) * 1000,
            )
          : null,
    );
  }

  /// Get visual indicator for status
  String get statusIcon {
    switch (status) {
      case MessageStatus.drafting:
        return '✏️';
      case MessageStatus.pending:
        return '⏳';
      case MessageStatus.sentDirect:
        return '✓';
      case MessageStatus.sentRelayed:
        return '↗';
      case MessageStatus.received:
        return '✓';
      case MessageStatus.delivered:
        return '✓✓';
      case MessageStatus.failed:
        return '⚠️';
    }
  }

  /// Get color code for status indicator
  String get statusColor {
    switch (status) {
      case MessageStatus.drafting:
        return 'gray';
      case MessageStatus.pending:
        return 'yellow';
      case MessageStatus.sentDirect:
        return 'green';
      case MessageStatus.sentRelayed:
        return 'orange';
      case MessageStatus.received:
        return 'blue';
      case MessageStatus.delivered:
        return 'green';
      case MessageStatus.failed:
        return 'red';
    }
  }

  @override
  String toString() {
    return 'MessageModel(id: $id, sender: $senderId, status: $status, time: $timestamp)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MessageModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
