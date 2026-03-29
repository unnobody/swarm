import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import '../bridges/mesh_core_bridge.dart';
import '../models/message_model.dart';
import '../models/peer_model.dart';

/// Network connection type
enum NetworkType {
  /// No connection
  offline,
  
  /// Bluetooth Low Energy (direct)
  ble,
  
  /// Wi-Fi Direct or local network
  wifiDirect,
  
  /// Internet via libp2p
  internet,
}

/// Network status information
class NetworkStatus {
  final NetworkType type;
  final bool isConnected;
  final int peerCount;
  final int reachablePeerCount;
  final bool canRelay;
  final String? errorMessage;

  NetworkStatus({
    this.type = NetworkType.offline,
    this.isConnected = false,
    this.peerCount = 0,
    this.reachablePeerCount = 0,
    this.canRelay = false,
    this.errorMessage,
  });

  NetworkStatus copyWith({
    NetworkType? type,
    bool? isConnected,
    int? peerCount,
    int? reachablePeerCount,
    bool? canRelay,
    String? errorMessage,
  }) {
    return NetworkStatus(
      type: type ?? this.type,
      isConnected: isConnected ?? this.isConnected,
      peerCount: peerCount ?? this.peerCount,
      reachablePeerCount: reachablePeerCount ?? this.reachablePeerCount,
      canRelay: canRelay ?? this.canRelay,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type.name,
      'is_connected': isConnected,
      'peer_count': peerCount,
      'reachable_peer_count': reachablePeerCount,
      'can_relay': canRelay,
      'error_message': errorMessage,
    };
  }
}

/// Service for handling message synchronization using CRDTs
class SyncService extends ChangeNotifier {
  final MeshCoreApi _meshCoreApi = MeshCoreApi();
  
  bool _isInitialized = false;
  bool _isSyncing = false;
  Uint8List? _syncDocument;
  final List<MessageModel> _pendingMessages = [];
  final Map<String, MessageModel> _messageCache = {};

  bool get isInitialized => _isInitialized;
  bool get isSyncing => _isSyncing;
  List<MessageModel> get pendingMessages => List.unmodifiable(_pendingMessages);
  int get messageCount => _messageCache.length;

  /// Initialize sync service with Automerge document
  Future<void> initialize() async {
    try {
      _syncDocument = await _meshCoreApi.createSyncDocument();
      _isInitialized = true;
      notifyListeners();
      debugPrint('✓ SyncService initialized with Automerge document');
    } catch (e) {
      debugPrint('✗ Failed to initialize SyncService: $e');
      rethrow;
    }
  }

  /// Add a new message to the sync document
  Future<void> addMessage(MessageModel message) async {
    if (!_isInitialized) {
      throw StateError('SyncService not initialized');
    }

    try {
      // In production, this would create an Automerge operation
      // For now, we cache the message locally
      _messageCache[message.id] = message;
      
      if (message.status == MessageStatus.pending) {
        _pendingMessages.add(message);
      }
      
      notifyListeners();
      debugPrint('✓ Message added to sync: ${message.id}');
    } catch (e) {
      debugPrint('✗ Error adding message: $e');
      rethrow;
    }
  }

  /// Apply changes received from another device
  Future<List<MessageModel>> applyChanges(Uint8List changes) async {
    if (!_isInitialized || _syncDocument == null) {
      throw StateError('SyncService not initialized');
    }

    _isSyncing = true;
    notifyListeners();

    try {
      final updatedDoc = await _meshCoreApi.applySyncChanges(
        document: _syncDocument!,
        changes: changes,
      );

      if (updatedDoc != null) {
        _syncDocument = updatedDoc;
      }

      // In production, parse the updated document and extract new messages
      // For now, return empty list
      final newMessages = <MessageModel>[];
      
      debugPrint('✓ Applied sync changes, ${newMessages.length} new messages');
      return newMessages;
    } catch (e) {
      debugPrint('✗ Error applying sync changes: $e');
      rethrow;
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  /// Get sync changes to send to other devices
  Future<Uint8List?> getChanges() async {
    if (!_isInitialized || _syncDocument == null) {
      return null;
    }

    try {
      // In production, generate incremental changes from Automerge
      // For now, return null
      return null;
    } catch (e) {
      debugPrint('✗ Error getting changes: $e');
      return null;
    }
  }

  /// Mark message as delivered
  Future<void> markDelivered(String messageId) async {
    final message = _messageCache[messageId];
    if (message != null) {
      _messageCache[messageId] = message.copyWith(
        status: MessageStatus.delivered,
        deliveredAt: DateTime.now(),
      );
      notifyListeners();
    }
  }

  /// Update message status after transmission
  Future<void> updateMessageStatus(
    String messageId,
    MessageStatus status, {
    ConnectionType? connectionType,
    int? hopCount,
  }) async {
    final message = _messageCache[messageId];
    if (message != null) {
      _messageCache[messageId] = message.copyWith(
        status: status,
        connectionType: connectionType,
        hopCount: hopCount,
      );
      
      // Remove from pending if no longer pending
      if (status != MessageStatus.pending) {
        _pendingMessages.removeWhere((m) => m.id == messageId);
      }
      
      notifyListeners();
    }
  }

  /// Get all messages for a conversation
  List<MessageModel> getMessagesForConversation(String peerId) {
    return _messageCache.values
        .where((m) => m.senderId == peerId || m.recipientId == peerId)
        .toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  /// Clear all data (for logout/reset)
  Future<void> clear() async {
    try {
      _syncDocument = await _meshCoreApi.createSyncDocument();
      _messageCache.clear();
      _pendingMessages.clear();
      notifyListeners();
      debugPrint('✓ SyncService cleared');
    } catch (e) {
      debugPrint('✗ Error clearing SyncService: $e');
      rethrow;
    }
  }
}
