import 'package:isar/isar.dart';
import 'message_entity.dart';
import 'peer_entity.dart';

/// Сервис локального хранилища на базе Isar
/// 
/// Обеспечивает:
/// - Хранение зашифрованных сообщений
/// - Управление контактами (пирами)
/// - Кэширование настроек приложения
/// - Офлайн-доступ к данным
class StorageService {
  static late Isar _isar;
  static bool _isInitialized = false;

  /// Инициализация хранилища
  static Future<void> initialize({String? path}) async {
    if (_isInitialized) return;

    // Инициализация Isar
    _isar = await Isar.open(
      [MessageEntitySchema, PeerEntitySchema],
      directory: path,
    );

    _isInitialized = true;
    print('StorageService initialized at: ${_isar.directory}');
  }

  /// Проверка инициализации
  static void ensureInitialized() {
    if (!_isInitialized) {
      throw Exception('StorageService not initialized. Call initialize() first.');
    }
  }

  // ==================== Методы для сообщений ====================

  /// Сохранить сообщение
  static Future<void> saveMessage(MessageEntity message) async {
    ensureInitialized();
    await _isar.writeTxn(() async {
      await _isar.messageEntities.put(message);
    });
  }

  /// Сохранить несколько сообщений
  static Future<void> saveMessages(List<MessageEntity> messages) async {
    ensureInitialized();
    await _isar.writeTxn(() async {
      await _isar.messageEntities.putAll(messages);
    });
  }

  /// Получить сообщение по UUID
  static Future<MessageEntity?> getMessageByUuid(String uuid) async {
    ensureInitialized();
    return await _isar.messageEntities
        .filter()
        .uuidEqualTo(uuid)
        .findFirst();
  }

  /// Получить все сообщения для чата с пиром
  static Future<List<MessageEntity>> getMessagesForPeer({
    required String peerId,
    String? currentUserId,
    int limit = 100,
    int offset = 0,
  }) async {
    ensureInitialized();
    
    final query = _isar.messageEntities.filter();
    
    // Фильтр: сообщения где пользователь является отправителем или получателем
    final filteredQuery = currentUserId != null
        ? query.or()
            .senderIdEqualTo(peerId)
            .and()
            .receiverIdEqualTo(currentUserId)
            .or()
            .senderIdEqualTo(currentUserId)
            .and()
            .receiverIdEqualTo(peerId)
        : query.senderIdEqualTo(peerId).or().receiverIdEqualTo(peerId);
    
    return await filteredQuery
        .sortByCreatedAtDesc()
        .offset(offset)
        .limit(limit)
        .findAll();
  }

  /// Обновить статус сообщения
  static Future<void> updateMessageStatus({
    required String uuid,
    required String status,
    DateTime? timestamp,
  }) async {
    ensureInitialized();
    await _isar.writeTxn(() async {
      final message = await getMessageByUuid(uuid);
      if (message != null) {
        message.status = status;
        
        // Установка временной метки в зависимости от статуса
        switch (status) {
          case 'sentDirect':
          case 'sentRelayed':
            message.sentAt = timestamp ?? DateTime.now();
            break;
          case 'delivered':
            message.deliveredAt = timestamp ?? DateTime.now();
            break;
          case 'received':
            message.readAt = timestamp ?? DateTime.now();
            break;
        }
        
        await _isar.messageEntities.put(message);
      }
    });
  }

  /// Удалить сообщение
  static Future<void> deleteMessage(String uuid) async {
    ensureInitialized();
    await _isar.writeTxn(() async {
      final message = await getMessageByUuid(uuid);
      if (message != null) {
        await _isar.messageEntities.delete(message.id);
      }
    });
  }

  /// Получить все несохраненные (не синхронизированные) сообщения
  static Future<List<MessageEntity>> getUnsyncedMessages() async {
    ensureInitialized();
    return await _isar.messageEntities
        .filter()
        .isSyncedEqualTo(false)
        .findAll();
  }

  /// Пометить сообщение как синхронизированное
  static Future<void> markMessageAsSynced(String uuid) async {
    ensureInitialized();
    await _isar.writeTxn(() async {
      final message = await getMessageByUuid(uuid);
      if (message != null) {
        message.isSynced = true;
        await _isar.messageEntities.put(message);
      }
    });
  }

  /// Очистить старые сообщения (для экономии места)
  static Future<int> cleanupOldMessages({
    required DateTime olderThan,
    int batchSize = 100,
  }) async {
    ensureInitialized();
    int deletedCount = 0;
    
    await _isar.writeTxn(() async {
      final oldMessages = await _isar.messageEntities
          .filter()
          .createdAtLessThan(olderThan)
          .limit(batchSize)
          .findAll();
      
      for (final message in oldMessages) {
        await _isar.messageEntities.delete(message.id);
        deletedCount++;
      }
    });
    
    return deletedCount;
  }

  // ==================== Методы для пиров (контактов) ====================

  /// Сохранить пира
  static Future<void> savePeer(PeerEntity peer) async {
    ensureInitialized();
    await _isar.writeTxn(() async {
      await _isar.peerEntities.put(peer);
    });
  }

  /// Получить пира по ID
  static Future<PeerEntity?> getPeerById(String peerId) async {
    ensureInitialized();
    return await _isar.peerEntities
        .filter()
        .peerIdEqualTo(peerId)
        .findFirst();
  }

  /// Получить всех пиров
  static Future<List<PeerEntity>> getAllPeers({
    bool includeBlocked = false,
    bool favoritesOnly = false,
  }) async {
    ensureInitialized();
    
    var query = _isar.peerEntities.filter();
    
    if (!includeBlocked) {
      query = query.isBlockedEqualTo(false);
    }
    
    if (favoritesOnly) {
      query = query.isFavoriteEqualTo(true);
    }
    
    return await query.sortByDisplayName().findAll();
  }

  /// Обновить статус пира
  static Future<void> updatePeerStatus({
    required String peerId,
    required String status,
    DateTime? lastSeen,
  }) async {
    ensureInitialized();
    await _isar.writeTxn(() async {
      final peer = await getPeerById(peerId);
      if (peer != null) {
        peer.status = status;
        if (lastSeen != null) {
          peer.lastSeen = lastSeen;
        }
        peer.updatedAt = DateTime.now();
        await _isar.peerEntities.put(peer);
      }
    });
  }

  /// Обновить уровень доверия
  static Future<void> updatePeerTrustLevel({
    required String peerId,
    required String trustLevel,
  }) async {
    ensureInitialized();
    await _isar.writeTxn(() async {
      final peer = await getPeerById(peerId);
      if (peer != null) {
        peer.trustLevel = trustLevel;
        peer.updatedAt = DateTime.now();
        await _isar.peerEntities.put(peer);
      }
    });
  }

  /// Добавить известный адрес пира (BLE MAC, IP и т.д.)
  static Future<void> addPeerAddress({
    required String peerId,
    required String address,
  }) async {
    ensureInitialized();
    await _isar.writeTxn(() async {
      final peer = await getPeerById(peerId);
      if (peer != null && !peer.knownAddresses.contains(address)) {
        peer.knownAddresses.add(address);
        peer.updatedAt = DateTime.now();
        await _isar.peerEntities.put(peer);
      }
    });
  }

  /// Удалить пира
  static Future<void> deletePeer(String peerId) async {
    ensureInitialized();
    await _isar.writeTxn(() async {
      final peer = await getPeerById(peerId);
      if (peer != null) {
        await _isar.peerEntities.delete(peer.id);
      }
    });
  }

  /// Поиск пиров по имени
  static Future<List<PeerEntity>> searchPeers(String query) async {
    ensureInitialized();
    return await _isar.peerEntities
        .filter()
        .displayNameContains(query, caseSensitive: false)
        .isBlockedEqualTo(false)
        .sortByDisplayName()
        .findAll();
  }

  // ==================== Утилиты ====================

  /// Получить статистику хранилища
  static Future<Map<String, dynamic>> getStorageStats() async {
    ensureInitialized();
    
    final messageCount = await _isar.messageEntities.count();
    final peerCount = await _isar.peerEntities.count();
    final unsyncedCount = await _isar.messageEntities
        .filter()
        .isSyncedEqualTo(false)
        .count();
    
    return {
      'totalMessages': messageCount,
      'totalPeers': peerCount,
      'unsyncedMessages': unsyncedCount,
      'databasePath': _isar.directory,
      'isInitialized': _isInitialized,
    };
  }

  /// Экспорт базы данных (для бэкапа)
  static Future<List<int>> exportDatabase() async {
    ensureInitialized();
    // В реальной реализации нужно экспортировать файлы Isar
    // Это упрощенная версия
    return [];
  }

  /// Импорт базы данных (из бэкапа)
  static Future<void> importDatabase(List<int> data) async {
    ensureInitialized();
    // В реальной реализации нужно импортировать файлы Isar
    // Это упрощенная версия
  }

  /// Закрыть соединение с базой данных
  static Future<void> close() async {
    if (_isInitialized) {
      await _isar.close();
      _isInitialized = false;
    }
  }
}
