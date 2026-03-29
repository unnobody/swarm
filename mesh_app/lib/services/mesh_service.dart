import 'package:flutter/foundation.dart';
import 'identity_service.dart';
import 'crypto_service.dart';
import 'sync_service.dart';
import 'transport_service.dart';
import '../models/message_model.dart';
import '../models/peer_model.dart';

/// High-level service orchestrating all mesh communication components
class MeshService extends ChangeNotifier {
  final IdentityService identityService;
  final CryptoService cryptoService;
  final SyncService syncService;
  final TransportService transportService;

  bool _isInitialized = false;
  bool _isReady = false;

  bool get isInitialized => _isInitialized;
  bool get isReady => _isReady;

  MeshService({
    IdentityService? identityService,
    CryptoService? cryptoService,
    SyncService? syncService,
    TransportService? transportService,
  })  : identityService = identityService ?? IdentityService(),
        cryptoService = cryptoService ?? CryptoService(),
        syncService = syncService ?? SyncService(),
        transportService = transportService ?? TransportService();

  /// Initialize all services
  Future<void> initialize() async {
    try {
      debugPrint('🚀 Initializing MeshService...');

      // Initialize crypto first (needed for identity)
      await cryptoService.initialize();
      debugPrint('  ✓ CryptoService ready');

      // Initialize sync service
      await syncService.initialize();
      debugPrint('  ✓ SyncService ready');

      // Initialize transport service
      await transportService.initialize();
      debugPrint('  ✓ TransportService ready');

      // Load or create identity
      await identityService.loadIdentity();
      
      if (!identityService.hasIdentity) {
        debugPrint('  ℹ No identity found, user needs to create one');
      } else {
        debugPrint('  ✓ Identity loaded');
      }

      _isInitialized = true;
      _setupEventListeners();
      notifyListeners();
      
      debugPrint('✅ MeshService initialized successfully');
    } catch (e) {
      debugPrint('✗ Failed to initialize MeshService: $e');
      rethrow;
    }
  }

  /// Setup event listeners between services
  void _setupEventListeners() {
    // Listen to transport events
    transportService.events.listen((event) {
      _handleTransportEvent(event);
    });
  }

  /// Handle incoming transport events
  void _handleTransportEvent(TransportEventData event) {
    switch (event.type) {
      case TransportEvent.peerDiscovered:
        debugPrint('📡 Peer discovered: ${event.peer?.effectiveDisplayName}');
        break;
        
      case TransportEvent.peerLost:
        debugPrint('📡 Peer lost: ${event.peer?.effectiveDisplayName}');
        break;
        
      case TransportEvent.messageReceived:
        _handleIncomingMessage(event.message!);
        break;
        
      case TransportEvent.messageSent:
        debugPrint('✓ Message sent: ${event.message?.id}');
        syncService.updateMessageStatus(
          event.message!.id,
          event.message!.status,
          connectionType: event.message!.connectionType,
          hopCount: event.message!.hopCount,
        );
        break;
        
      case TransportEvent.messageFailed:
        debugPrint('✗ Message failed: ${event.message?.id}, error: ${event.error}');
        syncService.updateMessageStatus(
          event.message!.id,
          MessageStatus.failed,
        );
        break;
        
      case TransportEvent.networkChanged:
        debugPrint('🌐 Network changed: ${event.metadata}');
        break;
    }
  }

  /// Process incoming message
  Future<void> _handleIncomingMessage(MessageModel encryptedMessage) async {
    try {
      // Find sender peer
      final sender = transportService.connectedPeers.values.firstWhere(
        (p) => p.id == encryptedMessage.senderId,
        orElse: () => throw ArgumentError('Unknown sender'),
      );

      // Decrypt message
      final decryptedMessage = await cryptoService.unwrapAndDecrypt(
        wrappedMessage: encryptedMessage.toMap(),
        sender: sender,
      );

      // Add to sync document
      await syncService.addMessage(decryptedMessage);
      
      debugPrint('✓ Message received and decrypted from ${sender.effectiveDisplayName}');
    } catch (e) {
      debugPrint('✗ Error handling incoming message: $e');
    }
  }

  /// Create new identity (onboarding)
  Future<void> createIdentity() async {
    await identityService.createIdentity();
    _isReady = true;
    notifyListeners();
  }

  /// Send a message to a peer
  Future<bool> sendMessage(String content, Peer recipient) async {
    if (!_isReady) {
      throw StateError('MeshService not ready (no identity)');
    }

    try {
      // Create message model
      final message = MessageModel(
        id: '${identityService.publicKey!.substring(0, 8)}_${DateTime.now().millisecondsSinceEpoch}',
        senderId: identityService.publicKey!,
        recipientId: recipient.id,
        content: content,
        timestamp: DateTime.now(),
        status: MessageStatus.pending,
      );

      // Encrypt message
      final wrappedData = await cryptoService.encryptAndWrap(
        content: content,
        recipient: recipient,
        senderId: identityService.publicKey!,
      );

      final encryptedMessage = MessageModel(
        id: message.id,
        senderId: message.senderId,
        recipientId: message.recipientId,
        content: '', // Content is in wrappedData
        timestamp: message.timestamp,
        status: MessageStatus.pending,
      );

      // Add to sync document
      await syncService.addMessage(message);

      // Send via transport
      return await transportService.sendMessage(encryptedMessage, recipient);
    } catch (e) {
      debugPrint('✗ Error sending message: $e');
      return false;
    }
  }

  /// Get messages for a conversation
  List<MessageModel> getConversationMessages(String peerId) {
    return syncService.getMessagesForConversation(peerId);
  }

  /// Start scanning for peers
  Future<void> startScanning() async {
    await transportService.startScanning();
  }

  /// Stop scanning for peers
  Future<void> stopScanning() async {
    await transportService.stopScanning();
  }

  /// Connect to a peer
  Future<bool> connectToPeer(Peer peer) async {
    return await transportService.connectToPeer(peer);
  }

  /// Update transport mode
  Future<void> setTransportMode(TransportMode mode) async {
    await transportService.setMode(mode);
  }

  /// Export identity as QR code data
  String exportIdentityQR() {
    return identityService.exportIdentityForQR();
  }

  /// Check if service is ready for messaging
  bool get canSendMessages => _isReady && identityService.hasIdentity;

  /// Dispose resources
  @override
  void dispose() {
    transportService.dispose();
    super.dispose();
  }
}
