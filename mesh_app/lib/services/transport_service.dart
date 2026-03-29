import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/message_model.dart';
import '../models/peer_model.dart';
import 'sync_service.dart';

/// Transport mode for mesh communication
enum TransportMode {
  /// Bluetooth Low Energy (Android Nearby / iOS Multipeer)
  localOnly,
  
  /// Internet via libp2p
  internetOnly,
  
  /// Hybrid: use both local and internet
  hybrid,
  
  /// Battery saver: minimal radio usage
  batterySaver,
}

/// Event types from transport layer
enum TransportEvent {
  /// New peer discovered nearby
  peerDiscovered,
  
  /// Peer lost connection
  peerLost,
  
  /// Message received
  messageReceived,
  
  /// Message sent successfully
  messageSent,
  
  /// Message send failed
  messageFailed,
  
  /// Connection initiated
  connectionInitiated,
  
  /// Connected to peer
  connected,
  
  /// Disconnected from peer
  disconnected,
  
  /// Network status changed
  networkChanged,
  
  /// Error occurred
  error,
}

/// Transport event data
class TransportEventData {
  final TransportEvent type;
  final Peer? peer;
  final MessageModel? message;
  final String? error;
  final Map<String, dynamic>? metadata;

  TransportEventData({
    required this.type,
    this.peer,
    this.message,
    this.error,
    this.metadata,
  });
}

/// Service for handling message transport across different protocols
class TransportService extends ChangeNotifier {
  static const MethodChannel _methodChannel = 
      MethodChannel('secure_mesh/transport');
  static const EventChannel _eventChannel = 
      EventChannel('secure_mesh/transport_events');

  bool _isInitialized = false;
  bool _isScanning = false;
  TransportMode _mode = TransportMode.hybrid;
  final List<Peer> _discoveredPeers = [];
  final Map<String, Peer> _connectedPeers = {};
  final StreamController<TransportEventData> _eventController = 
      StreamController<TransportEventData>.broadcast();
  StreamSubscription? _eventStreamSubscription;

  bool get isInitialized => _isInitialized;
  bool get isScanning => _isScanning;
  TransportMode get mode => _mode;
  List<Peer> get discoveredPeers => List.unmodifiable(_discoveredPeers);
  Map<String, Peer> get connectedPeers => Map.unmodifiable(_connectedPeers);
  Stream<TransportEventData> get events => _eventController.stream;

  /// Initialize transport service
  Future<void> initialize({
    TransportMode mode = TransportMode.hybrid,
    required String deviceName,
    String? deviceId,
  }) async {
    if (_isInitialized) {
      debugPrint('⚠️ TransportService already initialized');
      return;
    }

    try {
      _mode = mode;
      
      // Setup event listener from native platform
      _setupEventStream();
      
      // Call native initialize method
      await _methodChannel.invokeMethod<bool>('initialize', {
        'deviceName': deviceName,
        'deviceId': deviceId,
      });
      
      _isInitialized = true;
      notifyListeners();
      debugPrint('✓ TransportService initialized: $deviceName');
    } catch (e) {
      debugPrint('✗ Failed to initialize TransportService: $e');
      rethrow;
    }
  }

  /// Setup event stream from native platform
  void _setupEventStream() {
    _eventStreamSubscription?.cancel();
    
    _eventStreamSubscription = _eventChannel
        .receiveBroadcastStream()
        .listen((dynamic event) {
      _handleNativeEvent(event as Map<dynamic, dynamic>);
    }, onError: (error) {
      debugPrint('✗ Event stream error: $error');
      _eventController.add(TransportEventData(
        type: TransportEvent.error,
        error: error.toString(),
      ));
    });
    
    debugPrint('✓ Event stream listening started');
  }

  /// Handle events from native platform
  void _handleNativeEvent(Map<dynamic, dynamic> rawEvent) {
    try {
      final event = Map<String, dynamic>.from(rawEvent);
      final typeStr = event['type'] as String?;
      if (typeStr == null) return;

      final peerId = event['peerId'] as String?;
      final peerName = event['peerName'] as String?;
      final data = event['data'];
      final error = event['error'] as String?;

      // Convert data from List<int> to Uint8List if present
      Uint8List? byteData;
      if (data is List) {
        byteData = Uint8List.fromList(data.cast<int>());
      }

      TransportEvent? transportType;
      switch (typeStr) {
        case 'peerDiscovered':
          transportType = TransportEvent.peerDiscovered;
          break;
        case 'peerLost':
          transportType = TransportEvent.peerLost;
          break;
        case 'messageReceived':
          transportType = TransportEvent.messageReceived;
          break;
        case 'connectionInitiated':
          transportType = TransportEvent.connectionInitiated;
          break;
        case 'connected':
          transportType = TransportEvent.connected;
          break;
        case 'disconnected':
          transportType = TransportEvent.disconnected;
          break;
        case 'sendError':
          transportType = TransportEvent.messageFailed;
          break;
        case 'error':
          transportType = TransportEvent.error;
          break;
        default:
          debugPrint('⚠️ Unknown event type: $typeStr');
          return;
      }

      // Create peer if needed
      Peer? peer;
      if (peerId != null) {
        peer = Peer(
          publicKey: peerId,
          displayName: peerName ?? 'Unknown Peer',
          state: transportType == TransportEvent.disconnected || 
                 transportType == TransportEvent.peerLost
              ? PeerState.offline
              : PeerState.online,
          trustLevel: TrustLevel.unverified,
        );
        
        // Update peer lists
        if (transportType == TransportEvent.peerDiscovered) {
          addDiscoveredPeer(peer);
        } else if (transportType == TransportEvent.connected) {
          _connectedPeers[peer.publicKey] = peer;
        } else if (transportType == TransportEvent.disconnected ||
                   transportType == TransportEvent.peerLost) {
          removePeer(peer.publicKey);
        }
      }

      // Handle message received
      MessageModel? message;
      if (transportType == TransportEvent.messageReceived && byteData != null) {
        try {
          // In production: decrypt via CryptoService
          final jsonString = String.fromCharCodes(byteData);
          // Parse JSON to Map
          // For now, create placeholder
          message = MessageModel(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            content: '[Encrypted] ${byteData.length} bytes',
            senderId: peer?.publicKey ?? 'unknown',
            timestamp: DateTime.now(),
            status: MessageStatus.received,
            connectionType: ConnectionType.ble,
          );
        } catch (e) {
          debugPrint('✗ Error parsing received message: $e');
        }
      }

      _eventController.add(TransportEventData(
        type: transportType,
        peer: peer,
        message: message,
        error: error,
        metadata: event,
      ));

      debugPrint('✓ Native event: $typeStr ${peerId != null ? "from $peerId" : ""}');
    } catch (e) {
      debugPrint('✗ Error handling native event: $e');
    }
  }

  /// Start scanning for nearby peers
  Future<void> startScanning() async {
    if (!_isInitialized) {
      throw StateError('TransportService not initialized');
    }

    if (_isScanning) {
      return;
    }

    try {
      _isScanning = true;
      notifyListeners();
      
      // Call native methods to start discovery and advertising
      await Future.wait([
        _methodChannel.invokeMethod<void>('startDiscovery'),
        _methodChannel.invokeMethod<void>('startAdvertising'),
      ]);
      
      debugPrint('✓ Started scanning for peers');
    } catch (e) {
      debugPrint('✗ Error starting scan: $e');
      _isScanning = false;
      notifyListeners();
      rethrow;
    }
  }

  /// Stop scanning for peers
  Future<void> stopScanning() async {
    if (!_isScanning) {
      return;
    }

    try {
      _isScanning = false;
      
      // Call native methods to stop discovery and advertising
      await Future.wait([
        _methodChannel.invokeMethod<void>('stopDiscovery'),
        _methodChannel.invokeMethod<void>('stopAdvertising'),
      ]);
      
      notifyListeners();
      debugPrint('✓ Stopped scanning');
    } catch (e) {
      debugPrint('✗ Error stopping scan: $e');
      rethrow;
    }
  }

  /// Add a discovered peer
  void addDiscoveredPeer(Peer peer) {
    if (!_discoveredPeers.any((p) => p.publicKey == peer.publicKey)) {
      _discoveredPeers.add(peer);
      _eventController.add(TransportEventData(
        type: TransportEvent.peerDiscovered,
        peer: peer,
      ));
      notifyListeners();
      debugPrint('✓ Discovered peer: ${peer.effectiveDisplayName}');
    }
  }

  /// Remove a lost peer
  void removePeer(String publicKey) {
    final peer = _discoveredPeers.firstWhere(
      (p) => p.publicKey == publicKey,
      orElse: () => throw ArgumentError('Peer not found'),
    );
    
    _discoveredPeers.remove(peer);
    _connectedPeers.remove(publicKey);
    
    _eventController.add(TransportEventData(
      type: TransportEvent.peerLost,
      peer: peer,
    ));
    
    notifyListeners();
    debugPrint('✓ Lost peer: ${peer.effectiveDisplayName}');
  }

  /// Connect to a peer
  Future<bool> connectToPeer(Peer peer) async {
    try {
      // Call native method to connect
      await _methodChannel.invokeMethod<bool>('connectToPeer', {
        'peerId': peer.publicKey,
      });
      
      _connectedPeers[peer.publicKey] = peer.copyWith(
        state: PeerState.online,
      );
      
      notifyListeners();
      debugPrint('✓ Connected to peer: ${peer.effectiveDisplayName}');
      return true;
    } catch (e) {
      debugPrint('✗ Failed to connect to peer: $e');
      return false;
    }
  }

  /// Disconnect from a peer
  Future<void> disconnectFromPeer(String publicKey) async {
    final peer = _connectedPeers[publicKey];
    if (peer != null) {
      // Call native method to disconnect
      await _methodChannel.invokeMethod<void>('disconnectFromPeer', {
        'peerId': publicKey,
      });
      
      _connectedPeers.remove(publicKey);
      
      notifyListeners();
      debugPrint('✓ Disconnected from peer: ${peer.effectiveDisplayName}');
    }
  }

  /// Send a message to a peer
  Future<bool> sendMessage(MessageModel message, Peer recipient) async {
    if (!_isInitialized) {
      throw StateError('TransportService not initialized');
    }

    try {
      // Determine connection type based on peer state
      ConnectionType connectionType;
      if (_connectedPeers.containsKey(recipient.publicKey)) {
        connectionType = ConnectionType.ble; // Direct connection
      } else {
        connectionType = ConnectionType.meshRelay; // Via relay
      }

      // Update message status
      final updatedMessage = message.copyWith(
        status: connectionType == ConnectionType.ble
            ? MessageStatus.sentDirect
            : MessageStatus.sentRelayed,
        connectionType: connectionType,
      );

      // Serialize message to bytes
      // In production: encrypt via CryptoService first
      final messageBytes = message.content.codeUnits;

      // Call native send method
      final success = await _methodChannel.invokeMethod<bool>('sendToPeer', {
        'peerId': recipient.publicKey,
        'data': messageBytes,
      }) ?? false;

      if (success) {
        _eventController.add(TransportEventData(
          type: TransportEvent.messageSent,
          peer: recipient,
          message: updatedMessage,
        ));

        debugPrint('✓ Message sent to ${recipient.effectiveDisplayName}');
        return true;
      } else {
        throw Exception('Native send returned false');
      }
    } catch (e) {
      debugPrint('✗ Failed to send message: $e');
      
      _eventController.add(TransportEventData(
        type: TransportEvent.messageFailed,
        peer: recipient,
        message: message,
        error: e.toString(),
      ));
      
      return false;
    }
  }

  /// Broadcast message to all connected peers (for mesh relay)
  Future<int> broadcastMessage(MessageModel message) async {
    int successCount = 0;
    
    for (final peer in _connectedPeers.values) {
      if (peer.canRelay) {
        final success = await sendMessage(message, peer);
        if (success) successCount++;
      }
    }
    
    debugPrint('✓ Broadcast to $successCount relay peers');
    return successCount;
  }

  /// Handle incoming message from transport layer
  void handleIncomingMessage(Map<String, dynamic> rawData) {
    try {
      final message = MessageModel.fromMap(rawData);
      
      _eventController.add(TransportEventData(
        type: TransportEvent.messageReceived,
        message: message,
      ));
      
      debugPrint('✓ Received message: ${message.id}');
    } catch (e) {
      debugPrint('✗ Error handling incoming message: $e');
    }
  }

  /// Update transport mode
  Future<void> setMode(TransportMode newMode) async {
    if (_mode == newMode) return;

    _mode = newMode;
    
    // Adjust behavior based on mode
    switch (newMode) {
      case TransportMode.batterySaver:
        // Reduce scanning frequency, disable relay
        await stopScanning();
        break;
      case TransportMode.localOnly:
        // Disable internet transport
        break;
      case TransportMode.internetOnly:
        // Disable local transport
        break;
      case TransportMode.hybrid:
        // Enable both
        await startScanning();
        break;
    }
    
    _eventController.add(TransportEventData(
      type: TransportEvent.networkChanged,
      metadata: {'mode': newMode.name},
    ));
    
    notifyListeners();
    debugPrint('✓ Transport mode changed to ${newMode.name}');
  }

  /// Get signal strength for a peer (if available)
  int? getSignalStrength(String publicKey) {
    // In production: return RSSI from BLE/Multipeer
    // For now, return null
    return null;
  }

  /// Get connected peers from native platform
  Future<List<String>> getConnectedPeers() async {
    try {
      final result = await _methodChannel.invokeMethod<List<dynamic>>('getConnectedPeers');
      return result?.cast<String>() ?? [];
    } catch (e) {
      debugPrint('✗ Error getting connected peers: $e');
      return [];
    }
  }

  /// Get discovered peers from native platform
  Future<Map<String, String>> getDiscoveredPeers() async {
    try {
      final result = await _methodChannel.invokeMethod<Map<dynamic, dynamic>>('getDiscoveredPeers');
      if (result == null) return {};
      return result.map((key, value) => MapEntry(key.toString(), value.toString()));
    } catch (e) {
      debugPrint('✗ Error getting discovered peers: $e');
      return {};
    }
  }

  /// Stop all connections
  Future<void> stopAllConnections() async {
    try {
      await _methodChannel.invokeMethod<void>('stopAllConnections');
      _connectedPeers.clear();
      _discoveredPeers.clear();
      notifyListeners();
      debugPrint('✓ All connections stopped');
    } catch (e) {
      debugPrint('✗ Error stopping all connections: $e');
    }
  }

  /// Dispose resources
  @override
  void dispose() {
    stopScanning();
    stopAllConnections();
    _eventStreamSubscription?.cancel();
    _eventController.close();
    super.dispose();
  }
}
