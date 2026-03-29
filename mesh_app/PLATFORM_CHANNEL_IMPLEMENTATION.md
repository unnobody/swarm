# Platform Channel Glue Code - Реализация

## Обзор

Этот документ описывает реализацию Platform Channel Glue Code, который соединяет Dart код Flutter приложения с нативными транспортными модулями Android (Google Nearby Connections API) и iOS (Multipeer Connectivity Framework).

## Архитектура

```
┌─────────────────────────────────────────────────────────────┐
│                    Flutter Application                       │
│  ┌──────────────────────────────────────────────────────┐   │
│  │              TransportService (Dart)                  │   │
│  │  - MethodChannel: secure_mesh/transport               │   │
│  │  - EventChannel: secure_mesh/transport_events         │   │
│  └──────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
                              │
            ┌─────────────────┴─────────────────┐
            │                                   │
            ▼                                   ▼
┌─────────────────────────┐         ┌─────────────────────────┐
│      Android (Kotlin)   │         │       iOS (Swift)       │
│  ┌───────────────────┐  │         │  ┌───────────────────┐  │
│  │ MainActivity.java │  │         │  │ AppDelegate.swift │  │
│  │                   │  │         │  │                   │  │
│  │ - MethodChannel   │  │         │  │ - MethodChannel   │  │
│  │ - EventChannel    │  │         │  │ - EventChannel    │  │
│  └─────────┬─────────┘  │         │  └─────────┬─────────┘  │
│            │            │         │            │            │
│  ┌─────────▼─────────┐  │         │  ┌─────────▼─────────┐  │
│  │NearbyTransportMgr │  │         │  │MultipeerTransport │  │
│  │                   │  │         │  │     Manager       │  │
│  │ - Advertising     │  │         │  │ - Advertising     │  │
│  │ - Discovery       │  │         │  │ - Discovery       │  │
│  │ - Connections     │  │         │  │ - Connections     │  │
│  └───────────────────┘  │         │  └───────────────────┘  │
└─────────────────────────┘         └─────────────────────────┘
```

## Компоненты

### 1. Android Implementation

#### MainActivity.java
**Путь:** `mesh_app/android/app/src/main/java/com/securemesh/messenger/MainActivity.java`

**Ключевые функции:**
- Регистрация `MethodChannel` с именем `secure_mesh/transport`
- Регистрация `EventChannel` с именем `secure_mesh/transport_events`
- Обработка вызовов от Flutter:
  - `initialize(deviceName, deviceId)` - Инициализация транспорта
  - `startDiscovery()` - Начать поиск устройств
  - `stopDiscovery()` - Остановить поиск
  - `startAdvertising()` - Начать рекламу устройства
  - `stopAdvertising()` - Остановить рекламу
  - `connectToPeer(peerId)` - Подключиться к пиру
  - `disconnectFromPeer(peerId)` - Отключиться от пира
  - `sendToPeer(peerId, data)` - Отправить данные
  - `getConnectedPeers()` - Получить список подключенных пиров
  - `getDiscoveredPeers()` - Получить список обнаруженных пиров
  - `stopAllConnections()` - Остановить все подключения

**Разрешения:**
- BLUETOOTH_SCAN, BLUETOOTH_ADVERTISE, BLUETOOTH_CONNECT (Android 12+)
- ACCESS_FINE_LOCATION, ACCESS_COARSE_LOCATION (Android < 12)
- NEARBY_WIFI_DEVICES (Android 13+)

#### NearbyTransportManager.kt
**Путь:** `mesh_app/android/app/src/main/kotlin/com/securemesh/transport/NearbyTransportManager.kt`

**Функциональность:**
- Использование Google Nearby Connections API
- Стратегия P2P_CLUSTER для оптимальной mesh-работы
- Автоматическое управление BLE и Wi-Fi Direct
- Callback'и для событий подключения и получения данных

### 2. iOS Implementation

#### AppDelegate.swift
**Путь:** `mesh_app/ios/Runner/AppDelegate/AppDelegate.swift`

**Ключевые функции:**
- Регистрация `MethodChannel` с именем `secure_mesh/transport`
- Регистрация `EventChannel` с именем `secure_mesh/transport_events`
- Обработка тех же методов, что и на Android
- Генерация deviceId на основе identifierForVendor

#### MultipeerTransportManager.swift
**Путь:** `mesh_app/ios/Runner/Transport/MultipeerTransportManager.swift`

**Функциональность:**
- Использование Multipeer Connectivity Framework
- Автоматическое переключение между BLE и Wi-Fi
- Шифрование через `encryptionPreference: .required`
- Делегаты для MCSession, MCNearbyServiceAdvertiser, MCNearbyServiceBrowser

### 3. Dart Implementation

#### TransportService.dart
**Путь:** `mesh_app/lib/services/transport_service.dart`

**Обновленный функционал:**
- Интеграция с MethodChannel и EventChannel
- Асинхронная обработка событий от нативной платформы
- Автоматическое управление жизненным циклом подключений
- Поддержка различных режимов транспорта (localOnly, internetOnly, hybrid, batterySaver)

**Новые методы:**
```dart
Future<void> initialize({
  TransportMode mode = TransportMode.hybrid,
  required String deviceName,
  String? deviceId,
})

Future<void> startScanning()  // Вызывает native startDiscovery + startAdvertising
Future<void> stopScanning()   // Вызывает native stopDiscovery + stopAdvertising
Future<bool> connectToPeer(Peer peer)
Future<void> disconnectFromPeer(String publicKey)
Future<bool> sendMessage(MessageModel message, Peer recipient)
Future<List<String>> getConnectedPeers()
Future<Map<String, String>> getDiscoveredPeers()
Future<void> stopAllConnections()
```

## Поток данных

### 1. Инициализация
```
Flutter → MethodChannel.invoke('initialize') 
     → MainActivity/Delegate.createTransportManager()
     → Native transport starts advertising & discovery
     ← EventChannel.stream.listen() receives events
```

### 2. Обнаружение пира
```
Native (BLE/Multipeer) detects peer
     → NearbyTransportManager/MultipeerTransportManager
     → eventCallback({type: 'peerDiscovered', peerId: ..., peerName: ...})
     → EventChannel.sink.success(event)
     → TransportService._handleNativeEvent()
     → TransportService.addDiscoveredPeer()
     → notifyListeners() → UI updates
```

### 3. Отправка сообщения
```
Flutter UI calls transportService.sendMessage(message, peer)
     → Serialize message to bytes
     → MethodChannel.invoke('sendToPeer', {peerId, data})
     → MainActivity/Delegate.sendToPeer()
     → NearbyTransportManager/MultipeerTransportManager.sendToPeer()
     → Data transmitted over BLE/Wi-Fi
     ← Result returned to Flutter
```

### 4. Получение сообщения
```
Native receives data payload
     → PayloadCallback/session(_:didReceive:fromPeer:)
     → eventCallback({type: 'messageReceived', peerId, data})
     → EventChannel.stream → TransportService._handleNativeEvent()
     → Decrypt via CryptoService (future)
     → Store via StorageService
     → Notify UI
```

## Типы событий

| Событие | Описание | Данные |
|---------|----------|--------|
| `peerDiscovered` | Найден новый пир | `peerId`, `peerName` |
| `peerLost` | Пир потерялся | `peerId` |
| `connectionInitiated` | Начало подключения | `peerId`, `peerName` |
| `connected` | Подключение успешно | `peerId` |
| `disconnected` | Подключение разорвано | `peerId` |
| `messageReceived` | Получено сообщение | `peerId`, `data` (bytes) |
| `messageSent` | Сообщение отправлено | `peerId` |
| `sendError` | Ошибка отправки | `peerId`, `error` |
| `error` | Общая ошибка | `action`, `error` |

## Обработка ошибок

### Android
```java
try {
    // Native operation
} catch (Exception e) {
    sendEventToFlutter(Map.of(
        "type", "error",
        "action", "operationName",
        "error", e.getMessage()
    ));
    result.error("ERROR_CODE", e.getMessage(), null);
}
```

### iOS
```swift
do {
    // Native operation
} catch {
    sendEventToFlutter([
        "type": "error",
        "action": "operationName",
        "error": error.localizedDescription
    ])
    result(FlutterError(code: "ERROR_CODE", message: error.localizedDescription, details: nil))
}
```

### Dart
```dart
try {
    await _methodChannel.invokeMethod('operation');
} on PlatformException catch (e) {
    debugPrint('✗ Platform error: ${e.message}');
    rethrow;
} catch (e) {
    debugPrint('✗ Unknown error: $e');
    rethrow;
}
```

## Тестирование

### Unit тесты (Dart)
```dart
test('TransportService initializes correctly', () async {
  final service = TransportService();
  await service.initialize(
    deviceName: 'Test Device',
    deviceId: 'test-123',
  );
  expect(service.isInitialized, true);
});
```

### Integration тесты
1. Запустить приложение на двух устройствах
2. Вызвать `transportService.startScanning()`
3. Проверить событие `peerDiscovered`
4. Отправить сообщение
5. Проверить получение на другом устройстве

## Безопасность

### Текущая реализация
- iOS: `encryptionPreference: .required` в MCSession
- Android: Данные передаются через защищенный канал Nearby Connections

### Будущие улучшения
- Шифрование сообщений через CryptoService (libsodium) перед отправкой
- Верификация ключей пиров через QR-коды
- Использование Secure Enclave/Keystore для хранения ключей

## Производительность

### Оптимизации
- EventChannel использует broadcast stream для множественных подписчиков
- Байты конвертируются эффективно (Uint8List)
- Все callbacks выполняются на UI потоке для безопасности

### Ограничения
- BLE имеет ограничение ~20 байт на пакет (MTU)
- Большие сообщения разбиваются на части автоматически
- Фоновая работа ограничена iOS (требуется Background Modes)

## Следующие шаги

1. ✅ **Platform Channel Glue Code** - ЗАВЕРШЕНО
2. ⏳ **Интеграция с CryptoService** - Шифрование сообщений перед отправкой
3. ⏳ **Интеграция со StorageService** - Сохранение полученных сообщений
4. ⏳ **Background Service (Android)** - Foreground service для фоновой работы
5. ⏳ **Background Modes (iOS)** - Настройка Info.plist для фоновой работы
6. ⏳ **Push Notifications** - Firebase Cloud Messaging для wake-up

## Заключение

Platform Channel Glue Code успешно реализован и обеспечивает:
- ✅ Двустороннюю связь между Flutter и нативными платформами
- ✅ Автоматическое обнаружение и подключение пиров
- ✅ Передачу сообщений через BLE/Wi-Fi Direct
- ✅ Обработку ошибок и событий в реальном времени
- ✅ Единую абстракцию для Android и iOS

Приложение готово к сквозному тестированию на реальных устройствах!
