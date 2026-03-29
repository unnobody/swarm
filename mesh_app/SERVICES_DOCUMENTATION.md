# Dart Service Layer Implementation

## Обзор

Сервисный слой Dart обеспечивает высокоуровневый API для взаимодействия с Rust ядром через FFI и управляет бизнес-логикой приложения.

## Архитектура

```
┌─────────────────────────────────────────────────────────┐
│                    Flutter UI Layer                      │
│  (Screens, Widgets, Providers)                           │
└─────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────┐
│                   MeshService (Orchestrator)             │
│  - Координирует все сервисы                              │
│  - Обрабатывает события между компонентами               │
│  - Предоставляет единый API для UI                       │
└─────────────────────────────────────────────────────────┘
                            ↓
    ┌───────────┬───────────┬───────────┬───────────┐
    ↓           ↓           ↓           ↓           ↓
┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐
│Identity│ │ Crypto │ │  Sync  │ │Transport│ │ Models │
│Service │ │Service │ │Service │ │ Service │ │        │
└────────┘ └────────┘ └────────┘ └────────┘ └────────┘
    ↓           ↓           ↓           ↓
┌─────────────────────────────────────────────────────────┐
│              Flutter Rust Bridge (FFI)                   │
└─────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────┐
│                  Rust Core Library                       │
│  (libsodium, Automerge, libp2p)                          │
└─────────────────────────────────────────────────────────┘
```

## Компоненты

### 1. Модели данных (`lib/models/`)

#### `MessageModel`
Модель сообщения с поддержкой статусов mesh-сети:
- **Статусы**: `drafting`, `pending`, `sentDirect`, `sentRelayed`, `received`, `delivered`, `failed`
- **Типы подключения**: `ble`, `wifiDirect`, `internet`, `meshRelay`
- **Метрики**: `hopCount` (количество ретрансляций), timestamps

#### `PeerModel`
Модель контакта в mesh-сети:
- **Состояния**: `online`, `reachable`, `offline`, `unknown`
- **Уровни доверия**: `unverified`, `verified`, `trusted`, `blocked`
- **Методы**: QR-код экспорт/импорт, сериализация

### 2. Сервисы (`lib/services/`)

#### `CryptoService`
**Назначение**: Шифрование/дешифрование сообщений

**Основные методы**:
```dart
Future<void> initialize()
Future<EncryptedPayload> encryptMessage({
  required String messageContent,
  required String recipientPublicKey,
})
Future<String> decryptMessage({
  required EncryptedPayload encryptedPayload,
  required String senderPublicKey,
})
Future<Map<String, dynamic>> encryptAndWrap({...})
Future<MessageModel> unwrapAndDecrypt({...})
```

**Особенности**:
- Использует Rust libsodium через FFI
- Асинхронные операции с индикатором `_isProcessing`
- Вспомогательные методы для обёртки сообщений

---

#### `IdentityService`
**Назначение**: Управление криптографической идентичностью пользователя

**Основные методы**:
```dart
Future<void> loadIdentity()
Future<void> createIdentity()
String exportIdentityForQR()
Future<bool> importIdentityFromQR(String qrData)
Future<void> deleteIdentity()
```

**Свойства**:
- `identity`: текущая идентичность (publicKey, secretKey)
- `hasIdentity`: флаг наличия идентичности
- `isLoading`: статус загрузки

**Интеграция**:
- Загружает идентичность из Rust хранилища
- Экспорт/импорт через QR-коды для обмена контактами

---

#### `SyncService`
**Назначение**: Синхронизация сообщений через CRDT (Automerge)

**Основные методы**:
```dart
Future<void> initialize()
Future<void> addMessage(MessageModel message)
Future<List<MessageModel>> applyChanges(Uint8List changes)
Future<Uint8List?> getChanges()
Future<void> updateMessageStatus(String id, MessageStatus status)
List<MessageModel> getMessagesForConversation(String peerId)
```

**Особенности**:
- Хранит Automerge документ в памяти
- Отслеживает pending сообщения для отправки
- Разрешает конфликты при офлайн-синхронизации
- Методы для обновления статусов доставки

---

#### `TransportService`
**Назначение**: Транспортный уровень для mesh-коммуникации

**Режимы работы** (`TransportMode`):
- `localOnly`: Только BLE/Multipeer
- `internetOnly`: Только libp2p
- `hybrid`: Оба режима
- `batterySaver`: Энергосбережение

**Основные методы**:
```dart
Future<void> initialize({TransportMode mode})
Future<void> startScanning()
Future<void> stopScanning()
Future<bool> connectToPeer(Peer peer)
Future<bool> sendMessage(MessageModel message, Peer recipient)
Future<int> broadcastMessage(MessageModel message)
Stream<TransportEventData> get events
```

**События** (`TransportEvent`):
- `peerDiscovered`: Обнаружен новый пир
- `peerLost`: Пир потерял соединение
- `messageReceived`: Получено сообщение
- `messageSent`: Сообщение отправлено
- `messageFailed`: Ошибка отправки
- `networkChanged`: Изменение сети

**Платформенная адаптация**:
- **Android**: Google Nearby Connections API
- **iOS**: Multipeer Connectivity Framework
- **Internet**: libp2p (Rust)

---

#### `MeshService` (Оркестратор)
**Назначение**: Высокоуровневая координация всех сервисов

**Основные методы**:
```dart
Future<void> initialize()
Future<void> createIdentity()
Future<bool> sendMessage(String content, Peer recipient)
List<MessageModel> getConversationMessages(String peerId)
Future<void> startScanning()
Future<void> setTransportMode(TransportMode mode)
String exportIdentityQR()
bool get canSendMessages
```

**Функции оркестрации**:
1. Инициализирует все сервисы в правильном порядке
2. Подписывается на события транспорта
3. Обрабатывает входящие сообщения (дешифровка + синхронизация)
4. Обновляет статусы исходящих сообщений
5. Предоставляет единый API для UI слоя

---

## Примеры использования

### Инициализация приложения
```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Rust bridge
  await initMeshCoreBridge();
  
  final meshService = MeshService();
  await meshService.initialize();
  
  runApp(MyApp(meshService: meshService));
}
```

### Создание идентичности (Onboarding)
```dart
class OnboardingScreen extends StatelessWidget {
  final MeshService meshService;
  
  Future<void> _createIdentity() async {
    await meshService.createIdentity();
    // Navigate to main app
  }
  
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('Create your secure identity'),
        ElevatedButton(
          onPressed: _createIdentity,
          child: Text('Get Started'),
        ),
      ],
    );
  }
}
```

### Отправка сообщения
```dart
class ChatScreen extends StatefulWidget {
  final Peer peer;
  final MeshService meshService;
  
  Future<void> _sendMessage(String content) async {
    final success = await meshService.sendMessage(content, peer);
    
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Message sent!')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send')),
      );
    }
  }
}
```

### Просмотр сообщений
```dart
class ConversationView extends StatelessWidget {
  final String peerId;
  final MeshService meshService;
  
  @override
  Widget build(BuildContext context) {
    final messages = meshService.getConversationMessages(peerId);
    
    return ListView.builder(
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final message = messages[index];
        return MessageTile(
          message: message,
          statusIcon: message.statusIcon,
          color: message.statusColor,
        );
      },
    );
  }
}
```

### Мониторинг статуса сети
```dart
class NetworkStatusWidget extends StatelessWidget {
  final TransportService transportService;
  
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<TransportEventData>(
      stream: transportService.events,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          final event = snapshot.data!;
          
          switch (event.type) {
            case TransportEvent.peerDiscovered:
              return Badge(
                child: Icon(Icons.bluetooth_searching),
                label: Text('${transportService.discoveredPeers.length} peers'),
              );
            case TransportEvent.messageSent:
              return Icon(Icons.check_circle, color: Colors.green);
            case TransportEvent.messageFailed:
              return Icon(Icons.error, color: Colors.red);
            default:
              return Container();
          }
        }
        return Container();
      },
    );
  }
}
```

---

## Интеграция с платформой

### Android (Native Module)
Для интеграции с Google Nearby Connections API создайте Kotlin модуль:

```kotlin
// android/app/src/main/kotlin/.../NearbyPlugin.kt
class NearbyPlugin : MethodCallHandler {
    private var client: NearbyConnectionsClient? = null
    
    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "startAdvertising" -> startAdvertising(call.arguments(), result)
            "startDiscovery" -> startDiscovery(call.arguments(), result)
            "sendPayload" -> sendPayload(call.arguments(), result)
            // ...
        }
    }
}
```

### iOS (Native Module)
Для интеграции с Multipeer Connectivity Framework:

```swift
// ios/Runner/MultipeerPlugin.swift
public class MultipeerPlugin: NSObject, FlutterPlugin {
    private var session: MCSession?
    private var advertiser: MCNearbyServiceAdvertiser?
    private var browser: MCNearbyServiceBrowser?
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "startBrowsing": startBrowsing(args: call.arguments)
        case "sendData": sendData(args: call.arguments)
        // ...
        }
    }
}
```

---

## Безопасность

### Хранение ключей
- **Production**: Используйте Secure Enclave (iOS) / Keystore (Android)
- **Текущая реализация**: Хранение в оперативной памяти Rust

### Шифрование
- **Алгоритм**: Curve25519 + XSalsa20-Poly1305 (libsodium)
- **Протокол**: Асимметричное шифрование для каждого сообщения
- **Ключи**: Генерация при первом запуске, никогда не передаются по сети

### Верификация контактов
- QR-коды для обмена public key
- Визуальная верификация отпечатков ключей
- Предупреждение о MITM-атаках

---

## Тестирование

### Unit тесты
```dart
test('CryptoService encrypts and decrypts correctly', () async {
  final crypto = CryptoService();
  await crypto.initialize();
  
  final payload = await crypto.encryptMessage(
    messageContent: 'Hello',
    recipientPublicKey: testPublicKey,
  );
  
  final decrypted = await crypto.decryptMessage(
    encryptedPayload: payload,
    senderPublicKey: testPublicKey,
  );
  
  expect(decrypted, equals('Hello'));
});
```

### Integration тесты
```dart
testWidgets('Full message flow', (tester) async {
  final service1 = MeshService();
  final service2 = MeshService();
  
  await service1.initialize();
  await service2.initialize();
  
  // Create identities
  await service1.createIdentity();
  await service2.createIdentity();
  
  // Send message
  final peer = Peer(
    id: 'test',
    publicKey: service2.identityService.publicKey!,
  );
  
  await service1.sendMessage('Hello', peer);
  
  // Verify received
  final messages = service2.getConversationMessages('peer1');
  expect(messages.length, equals(1));
  expect(messages.first.content, equals('Hello'));
});
```

---

## Следующие шаги

1. ✅ **Нативные транспорты**: Реализованы (Android Nearby + iOS Multipeer)
2. ⏳ **Persistent storage**: Добавить локальную БД (Hive/Isar) для хранения сообщений
3. ⏳ **Push notifications**: Интегрировать Firebase Cloud Messaging для wake-up
4. ⏳ **libp2p integration**: Полноценная настройка интернет-транспорта
5. ⏳ **Automerge operations**: Реальная реализация CRDT операций вместо заглушек
6. ⏳ **Background execution**: Настройка фоновой работы для Android/iOS
7. ⏳ **Mesh ретрансляция**: Store-and-forward логика для офлайн доставки
