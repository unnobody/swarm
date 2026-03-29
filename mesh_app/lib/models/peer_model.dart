/// Peer connection state
enum PeerState {
  /// Peer is directly connected (BLE/WiFi Direct)
  online,
  
  /// Peer is reachable via mesh relay
  reachable,
  
  /// Peer is offline but known
  offline,
  
  /// Peer state unknown
  unknown,
}

/// Peer trust level
enum TrustLevel {
  /// Not verified
  unverified,
  
  /// Verified via QR code scan
  verified,
  
  /// Trusted contact (manually approved)
  trusted,
  
  /// Blocked peer
  blocked,
}

/// Peer model representing a contact in the mesh network
class Peer {
  final String id;
  final String publicKey;
  final String? displayName;
  final String? alias; // User-defined name
  final PeerState state;
  final TrustLevel trustLevel;
  final DateTime? lastSeen;
  final DateTime? addedAt;
  final List<String>? sharedChannels; // Channel IDs we both participate in
  final int? hopDistance; // hops to reach this peer (for mesh routing)
  final bool canRelay; // Can this peer relay messages for others?

  Peer({
    required this.id,
    required this.publicKey,
    this.displayName,
    this.alias,
    this.state = PeerState.unknown,
    this.trustLevel = TrustLevel.unverified,
    this.lastSeen,
    DateTime? addedAt,
    this.sharedChannels,
    this.hopDistance,
    this.canRelay = false,
  }) : addedAt = addedAt ?? DateTime.now();

  /// Create a copy with updated fields
  Peer copyWith({
    String? id,
    String? publicKey,
    String? displayName,
    String? alias,
    PeerState? state,
    TrustLevel? trustLevel,
    DateTime? lastSeen,
    DateTime? addedAt,
    List<String>? sharedChannels,
    int? hopDistance,
    bool? canRelay,
  }) {
    return Peer(
      id: id ?? this.id,
      publicKey: publicKey ?? this.publicKey,
      displayName: displayName ?? this.displayName,
      alias: alias ?? this.alias,
      state: state ?? this.state,
      trustLevel: trustLevel ?? this.trustLevel,
      lastSeen: lastSeen ?? this.lastSeen,
      addedAt: addedAt ?? this.addedAt,
      sharedChannels: sharedChannels ?? this.sharedChannels,
      hopDistance: hopDistance ?? this.hopDistance,
      canRelay: canRelay ?? this.canRelay,
    );
  }

  /// Get display name (alias takes precedence)
  String get effectiveDisplayName => alias ?? displayName ?? 'Unknown Peer';

  /// Check if peer is currently reachable
  bool get isReachable => 
      state == PeerState.online || state == PeerState.reachable;

  /// Check if peer is verified
  bool get isVerified => 
      trustLevel == TrustLevel.verified || trustLevel == TrustLevel.trusted;

  /// Convert to map for serialization
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'public_key': publicKey,
      'display_name': displayName,
      'alias': alias,
      'state': state.name,
      'trust_level': trustLevel.name,
      'last_seen': lastSeen?.millisecondsSinceEpoch ~/ 1000,
      'added_at': addedAt!.millisecondsSinceEpoch ~/ 1000,
      'shared_channels': sharedChannels ?? [],
      'hop_distance': hopDistance,
      'can_relay': canRelay,
    };
  }

  /// Create from map (deserialization)
  factory Peer.fromMap(Map<String, dynamic> map) {
    return Peer(
      id: map['id'] as String,
      publicKey: map['public_key'] as String,
      displayName: map['display_name'] as String?,
      alias: map['alias'] as String?,
      state: PeerState.values.firstWhere(
        (e) => e.name == map['state'],
        orElse: () => PeerState.unknown,
      ),
      trustLevel: TrustLevel.values.firstWhere(
        (e) => e.name == map['trust_level'],
        orElse: () => TrustLevel.unverified,
      ),
      lastSeen: map['last_seen'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              (map['last_seen'] as int) * 1000,
            )
          : null,
      addedAt: map['added_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              (map['added_at'] as int) * 1000,
            )
          : null,
      sharedChannels: map['shared_channels'] != null
          ? List<String>.from(map['shared_channels'] as List)
          : null,
      hopDistance: map['hop_distance'] as int?,
      canRelay: map['can_relay'] as bool? ?? false,
    );
  }

  /// Generate QR code data for peer exchange
  String toQRData() {
    // Format: mesh://PUBLIC_KEY?name=DisplayName&verified=true
    final params = <String>[];
    if (displayName != null) {
      params.add('name=${Uri.encodeComponent(displayName!)}');
    }
    params.add('verified=$isVerified');
    
    return 'mesh://$publicKey?${params.join('&')}';
  }

  /// Parse peer from QR code data
  static Peer? fromQRData(String qrData) {
    try {
      if (!qrData.startsWith('mesh://')) return null;
      
      final uri = Uri.parse(qrData);
      final publicKey = uri.host;
      
      if (publicKey.isEmpty) return null;
      
      final nameParam = uri.queryParameters['name'];
      final displayName = nameParam != null 
          ? Uri.decodeComponent(nameParam) 
          : null;
      
      return Peer(
        id: publicKey.substring(0, 16), // Use first 16 chars as ID
        publicKey: publicKey,
        displayName: displayName,
        trustLevel: uri.queryParameters['verified'] == 'true'
            ? TrustLevel.verified
            : TrustLevel.unverified,
      );
    } catch (e) {
      return null;
    }
  }

  @override
  String toString() {
    return 'Peer(id: $id, name: $effectiveDisplayName, state: $state)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Peer && other.publicKey == publicKey;
  }

  @override
  int get hashCode => publicKey.hashCode;
}
