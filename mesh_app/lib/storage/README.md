# Локальное хранилище данных

## Обзор

Модуль локального хранилища обеспечивает офлайн-доступ к данным мессенджера, используя две базы данных для разных сценариев:

- **Isar** - основное хранилище для сообщений и контактов (ACID-транзакции, индексы)
- **Hive** - легкое хранилище для настроек и кэша (быстрый доступ)

## Архитектура

```
lib/storage/
├── message_entity.dart      # Модель сообщения для Isar
├── peer_entity.dart         # Модель контакта для Isar  
├── storage_service.dart     # Сервис работы с Isar (сообщения/пиры)
└── settings_service.dart    # Сервис работы с Hive (настройки)
```

## Компоненты

### 1. MessageEntity (message_entity.dart)

Модель для хранения зашифрованных сообщений в базе данных Isar.

**Поля:**
- `uuid` - уникальный идентификатор сообщения
- `senderId`, `receiverId` - участники диалога
- `content` - зашифрованный контент
- `status` - статус доставки (7 состояний)
- `connectionType` - тип соединения (BLE, WiFi, Internet, Mesh)
- `hopCount` - количество прыжков в mesh-сети
- `syncPatch` - binary patch для CRDT синхронизации
- Временные метки (`createdAt`, `sentAt`, `deliveredAt`, `readAt`)

**Особенности:**
- Уникальный индекс по `uuid` для быстрого поиска
- Конвертация в/из доменной модели `MessageModel`
- Поддержка бинарных данных для Automerge patches

### 2. PeerEntity (peer_entity.dart)

Модель для хранения контактов (пиров) в базе данных Isar.

**Поля:**
- `peerId` - уникальный ID пира (DID или публичный ключ)
- `displayName` - отображаемое имя
- `publicKey` - публичный ключ для шифрования
- `status` - состояние подключения (online/reachable/offline)
- `trustLevel` - уровень доверия (unverified/verified/trusted/blocked)
- `knownAddresses` - известные адреса (BLE MAC, IP)
- `connectionQuality` - качество соединения (0-100)

**Особенности:**
- Уникальный индекс по `peerId`
- Флаги `isFavorite`, `isBlocked`
- Автоматическое обновление `updatedAt`

### 3. StorageService (storage_service.dart)

Сервис для работы с основным хранилищем Isar.

**Методы для сообщений:**
```dart
// CRUD операции
saveMessage(MessageEntity)
saveMessages(List<MessageEntity>)
getMessageByUuid(String)
getMessagesForPeer({peerId, currentUserId, limit, offset})

// Статусы
updateMessageStatus({uuid, status, timestamp})
markMessageAsSynced(String uuid)

// Синхронизация
getUnsyncedMessages()

// Управление
deleteMessage(String uuid)
cleanupOldMessages({olderThan, batchSize})
```

**Методы для пиров:**
```dart
// CRUD операции
savePeer(PeerEntity)
getPeerById(String peerId)
getAllPeers({includeBlocked, favoritesOnly})

// Обновление состояния
updatePeerStatus({peerId, status, lastSeen})
updatePeerTrustLevel({peerId, trustLevel})
addPeerAddress({peerId, address})

// Поиск
searchPeers(String query)
deletePeer(String peerId)
```

**Утилиты:**
```dart
getStorageStats() // Статистика хранилища
exportDatabase()  // Экспорт для бэкапа
importDatabase()  // Импорт из бэкапа
close()           // Закрытие соединения
```

### 4. SettingsService (settings_service.dart)

Сервис для работы с настройками приложения на базе Hive.

**Настройки пользователя:**
- `userId`, `displayName` - идентичность
- `privacyMode` - максимальная приватность с ретрансляцией
- `batterySaverMode` - экономия батареи (только свои сообщения)
- `autoRelay` - автоматическая ретрансляция чужих сообщений

**Настройки UI:**
- `theme` - тема (light/dark/system)
- `language` - язык интерфейса
- `notificationsEnabled` - уведомления

**Кэш:**
- `lastSyncTime` - время последней синхронизации
- `nearbyPeers` - список nearby-пиров
- `networkStats` - статистика сети

**Методы:**
```dart
// Инициализация
initialize()

// Настройки
getUserId(), setUserId()
getPrivacyMode(), setPrivacyMode()
getBatterySaverMode(), setBatterySaverMode()
getTheme(), setTheme()

// Кэш
getLastSyncTime(), setLastSyncTime()
getNearbyPeers(), setNearbyPeers()
getNetworkStats(), setNetworkStats()

// Утилиты
getAllSettings()
resetSettings()
exportSettings()
importSettings()
clearCache()
close()
```

## Использование

### Инициализация при старте приложения

```dart
import 'package:mesh_secure/storage/storage_service.dart';
import 'package:mesh_secure/storage/settings_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Инициализация хранилищ
  await StorageService.initialize();
  await SettingsService.initialize();
  
  runApp(MyApp());
}
```

### Сохранение сообщения

```dart
import 'package:mesh_secure/storage/storage_service.dart';
import 'package:mesh_secure/storage/message_entity.dart';

// Создание实体 из модели
final message = MessageEntity.fromModel(messageModel);

// Сохранение в базу
await StorageService.saveMessage(message);

// Обновление статуса после отправки
await StorageService.updateMessageStatus(
  uuid: message.uuid,
  status: 'sentDirect',
);
```

### Работа с контактами

```dart
// Сохранение нового контакта
final peer = PeerEntity.fromModel(peerModel);
await StorageService.savePeer(peer);

// Получение всех контактов
final peers = await StorageService.getAllPeers();

// Обновление статуса при подключении
await StorageService.updatePeerStatus(
  peerId: peer.peerId,
  status: 'online',
  lastSeen: DateTime.now(),
);

// Поиск контактов
final results = await StorageService.searchPeers('Alice');
```

### Управление настройками

```dart
// Включение режима приватности
await SettingsService.setPrivacyMode(true);

// Проверка режима экономии батареи
if (SettingsService.getBatterySaverMode()) {
  // Отключить ретрансляцию чужих сообщений
}

// Сохранение времени синхронизации
await SettingsService.setLastSyncTime(DateTime.now());

// Получение кэша nearby-пиров
final nearbyPeerIds = SettingsService.getNearbyPeers();
```

### Получение сообщений для чата

```dart
// Пагинация сообщений
final messages = await StorageService.getMessagesForPeer(
  peerId: targetPeerId,
  currentUserId: currentUserId,
  limit: 50,
  offset: 0,
);

// Конвертация в доменные модели
final messageModels = messages.map((e) => e.toModel()).toList();
```

### Синхронизация офлайн-сообщений

```dart
// Получить все несохраненные сообщения
final unsynced = await StorageService.getUnsyncedMessages();

// Отправить через транспорт
for (final message in unsynced) {
  await transportService.send(message);
}

// Пометить как синхронизированные
for (final message in unsynced) {
  await StorageService.markMessageAsSynced(message.uuid);
}
```

### Очистка старых данных

```dart
// Удалить сообщения старше 30 дней
final thirtyDaysAgo = DateTime.now().subtract(Duration(days: 30));
final deletedCount = await StorageService.cleanupOldMessages(
  olderThan: thirtyDaysAgo,
  batchSize: 100,
);

print('Deleted $deletedCount old messages');
```

## Производительность

### Индексы

Isar использует индексы для ускорения поиска:
- `uuid` - уникальный индекс для быстрого поиска сообщений
- `peerId` - уникальный индекс для поиска контактов

### Транзакции

Все операции записи выполняются в транзакциях для обеспечения целостности данных:

```dart
await _isar.writeTxn(() async {
  await _isar.messageEntities.put(message);
});
```

### Пагинация

Для больших списков сообщений используйте пагинацию:

```dart
final messages = await StorageService.getMessagesForPeer(
  peerId: peerId,
  limit: 50,
  offset: pageNumber * 50,
);
```

## Безопасность

### Шифрование данных

- Сообщения хранятся в **зашифрованном виде** (encryptedContent)
- Ключи шифрования хранятся в Secure Enclave/Keystore (не в базе!)
- Isar не шифрует данные автоматически - используйте шифрование на уровне модели

### Изоляция данных

- Hive и Isar используют отдельные файлы базы данных
- Настройки и кэш изолированы от основных данных
- Возможность отдельного бэкапа настроек

## Миграции

При изменении схемы данных потребуется миграция:

```dart
// Пример миграции (будущая версия)
_isar = await Isar.open(
  [MessageEntitySchema, PeerEntitySchema],
  migration: (migration, oldVersion) {
    if (oldVersion < 2) {
      // Добавить новое поле
      migration.renameField<MessageEntity>('oldName', 'newName');
    }
  },
);
```

## Тестирование

### Моки для тестов

```dart
// В тестах используйте mock-реализацию
class MockStorageService implements StorageService {
  final Map<String, MessageEntity> _messages = {};
  
  @override
  Future<void> saveMessage(MessageEntity message) async {
    _messages[message.uuid] = message;
  }
  
  @override
  Future<MessageEntity?> getMessageByUuid(String uuid) async {
    return _messages[uuid];
  }
}
```

## Ограничения

1. **Размер базы**: Isar хорошо масштабируется, но рекомендуется периодически очищать старые сообщения
2. **Потокобезопасность**: Все методы статические и потокобезопасные
3. **Инициализация**: Обязательно вызывайте `initialize()` перед использованием
4. **Закрытие**: Вызывайте `close()` при завершении работы приложения

## Следующие шаги

1. ✅ Реализация моделей данных (MessageEntity, PeerEntity)
2. ✅ Реализация StorageService для Isar
3. ✅ Реализация SettingsService для Hive
4. ⏳ Интеграция с MeshService
5. ⏳ Добавление шифрования базы данных (опционально)
6. ⏳ Реализация миграций схемы
7. ⏳ Unit-тесты для сервисов хранилища
