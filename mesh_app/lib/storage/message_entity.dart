import 'package:isar/isar.dart';
import '../models/message_model.dart';
import '../models/peer_model.dart';

/// Модель сообщения для хранения в Isar
part 'message_entity.g.dart';

@collection
class MessageEntity {
  Id id = Isar.autoIncrement; // Автоматический ID

  @Index(unique: true)
  late String uuid; // Уникальный ID сообщения из модели

  late String senderId;
  late String receiverId;
  late String content; // Зашифрованный контент
  late String messageType; // text, image, file, etc.
  
  // Статусы и метрики
  late String status; // drafting, pending, sentDirect, etc.
  late String connectionType; // ble, wifiDirect, internet, etc.
  int hopCount = 0;
  
  // Временные метки
  late DateTime createdAt;
  DateTime? sentAt;
  DateTime? deliveredAt;
  DateTime? readAt;
  
  // Синхронизация
  late List<int> syncPatch; // Binary patch от Automerge
  bool isSynced = false;
  
  // Метаданные
  Map<String, dynamic>? metadata;

  /// Конвертация из доменной модели
  factory MessageEntity.fromModel(MessageModel model) {
    return MessageEntity()
      ..uuid = model.id
      ..senderId = model.senderId
      ..receiverId = model.receiverId
      ..content = model.encryptedContent ?? model.content
      ..messageType = model.type.name
      ..status = model.status.name
      ..connectionType = model.connectionType.name
      ..hopCount = model.hopCount
      ..createdAt = model.createdAt
      ..sentAt = model.sentAt
      ..deliveredAt = model.deliveredAt
      ..readAt = model.readAt
      ..syncPatch = model.syncPatch
      ..isSynced = model.isSynced
      ..metadata = model.metadata;
  }

  /// Конвертация в доменную модель
  MessageModel toModel() {
    return MessageModel(
      id: uuid,
      senderId: senderId,
      receiverId: receiverId,
      content: content,
      type: MessageType.values.firstWhere(
        (e) => e.name == messageType,
        orElse: () => MessageType.text,
      ),
      status: MessageStatus.values.firstWhere(
        (e) => e.name == status,
        orElse: () => MessageStatus.drafting,
      ),
      connectionType: ConnectionType.values.firstWhere(
        (e) => e.name == connectionType,
        orElse: () => ConnectionType.unknown,
      ),
      hopCount: hopCount,
      createdAt: createdAt,
      sentAt: sentAt,
      deliveredAt: deliveredAt,
      readAt: readAt,
      syncPatch: syncPatch,
      isSynced: isSynced,
      metadata: metadata,
    );
  }
}

/// Модель контакта для хранения в Isar
part 'peer_entity.g.dart';

@collection
class PeerEntity {
  Id id = Isar.autoIncrement;

  @Index(unique: true)
  late String peerId; // Уникальный ID пира (DID или публичный ключ)

  late String displayName;
  String? publicKey;
  String? encryptedIdentity; // Зашифрованная идентичность
  
  // Состояние
  late String status; // online, reachable, offline, unknown
  late String trustLevel; // unverified, verified, trusted, blocked
  
  // Информация о соединении
  DateTime? lastSeen;
  List<String> knownAddresses = []; // BLE MAC, IP addresses, etc.
  int connectionQuality = 0; // 0-100
  
  // Метаданные
  DateTime createdAt = DateTime.now();
  DateTime updatedAt = DateTime.now();
  Map<String, dynamic>? metadata;
  bool isFavorite = false;
  bool isBlocked = false;

  /// Конвертация из доменной модели
  factory PeerEntity.fromModel(PeerModel model) {
    return PeerEntity()
      ..peerId = model.id
      ..displayName = model.displayName
      ..publicKey = model.publicKey
      ..encryptedIdentity = model.encryptedIdentity
      ..status = model.status.name
      ..trustLevel = model.trustLevel.name
      ..lastSeen = model.lastSeen
      ..knownAddresses = model.knownAddresses
      ..connectionQuality = model.connectionQuality
      ..createdAt = model.createdAt
      ..updatedAt = model.updatedAt
      ..metadata = model.metadata
      ..isFavorite = model.isFavorite
      ..isBlocked = model.isBlocked;
  }

  /// Конвертация в доменную модель
  PeerModel toModel() {
    return PeerModel(
      id: peerId,
      displayName: displayName,
      publicKey: publicKey,
      encryptedIdentity: encryptedIdentity,
      status: PeerStatus.values.firstWhere(
        (e) => e.name == status,
        orElse: () => PeerStatus.unknown,
      ),
      trustLevel: TrustLevel.values.firstWhere(
        (e) => e.name == trustLevel,
        orElse: () => TrustLevel.unverified,
      ),
      lastSeen: lastSeen,
      knownAddresses: knownAddresses,
      connectionQuality: connectionQuality,
      createdAt: createdAt,
      updatedAt: updatedAt,
      metadata: metadata,
      isFavorite: isFavorite,
      isBlocked: isBlocked,
    );
  }
}
