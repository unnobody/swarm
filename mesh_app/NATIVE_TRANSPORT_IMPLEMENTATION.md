# Native Transport Modules Implementation Guide

## Обзор реализации

Нативные транспортные модули обеспечивают связь между устройствами через локальные беспроводные технологии (BLE, Wi-Fi Direct) без необходимости в интернете.

### Архитектура

```
┌─────────────────────────────────────────────────────────────┐
│                    Flutter Application                       │
│  ┌──────────────────────────────────────────────────────┐   │
│  │         NativeTransportChannel (Dart)                 │   │
│  └──────────────────────────────────────────────────────┘   │
│                            │                                 │
│         MethodChannel / EventChannel                         │
└────────────────────────────┼─────────────────────────────────┘
                             │
            ┌────────────────┴────────────────┐
            │                                 │
    ┌───────▼────────┐              ┌────────▼────────┐
    │    Android     │              │      iOS        │
    │  MainActivity  │              │   AppDelegate   │
    │     (Java)     │              │    (Swift)      │
    └───────┬────────┘              └────────┬────────┘
            │                                │
    ┌───────▼────────┐              ┌───────▼────────┐
    │ NearbyTransport│              │ MultipeerTrans │
    │   Manager      │              │   portManager  │
    │    (Kotlin)    │              │    (Swift)     │
    └───────┬────────┘              └───────┬────────┘
            │                                │
    ┌───────▼────────┐              ┌───────▼────────┐
    │ Google Nearby  │              │   Multipeer    │
    │ Connections    │              │  Connectivity  │
    │     API        │              │   Framework    │
    └────────────────┘              └────────────────┘
```

## Компоненты

### 1. Dart Layer (`lib/services/native_transport_channel.dart`)

**Назначение:** Единый интерфейс для вызова нативного кода из Flutter.

**Основные методы:**
- `initialize()` - Инициализация транспорта
- `startDiscovery()` / `stopDiscovery()` - Управление поиском устройств
- `startAdvertising()` / `stopAdvertising()` - Управление рекламой устройства
- `connectToPeer()` / `disconnectFromPeer()` - Управление подключениями
- `sendToPeer()` - Отправка зашифрованных данных

**События:**
- `peerDiscovered` - Обнаружено новое устройство
- `peerLost` - Устройство потеряно
- `messageReceived` - Получены данные от пира
- `connected` / `disconnected` - Изменение состояния подключения
- `error` - Ошибка транспорта

### 2. Android Implementation

#### 2.1 MainActivity (`android/app/src/main/java/com/securemesh/messenger/MainActivity.java`)

**Назначение:** Точка входа для Android приложения, регистрация каналов связи.

**Ключевые функции:**
- Регистрация `MethodChannel` для синхронных вызовов
- Регистрация `EventChannel` для потоковой передачи событий
- Запрос runtime разрешений (Bluetooth, Location, WiFi)
- Маршрутизация вызовов к `NearbyTransportManager`

**Разрешения:**
```xml
<!-- Android 11 и ниже -->
<uses-permission android:name="android.permission.BLUETOOTH" />
<uses-permission android:name="android.permission.BLUETOOTH_ADMIN" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />

<!-- Android 12+ -->
<uses-permission android:name="android.permission.BLUETOOTH_SCAN" />
<uses-permission android:name="android.permission.BLUETOOTH_ADVERTISE" />
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />

<!-- Android 13+ -->
<uses-permission android:name="android.permission.NEARBY_WIFI_DEVICES" />
```

#### 2.2 NearbyTransportManager (`android/app/src/main/kotlin/com/securemesh/transport/NearbyTransportManager.kt`)

**Назначение:** Обертка над Google Nearby Connections API.

**Стратегия подключения:** `P2P_CLUSTER`
- Автоматический выбор между BLE и Wi-Fi Direct
- Оптимально для mesh-сетей с несколькими устройствами
- Поддержка работы в фоне (с ограничениями)

**Особенности:**
- Автоматическое принятие входящих подключений
- Автоматическая попытка подключения к обнаруженным устройствам
- Преобразование `ByteArray` → `ArrayList<Int>` для передачи во Flutter

### 3. iOS Implementation

#### 3.1 AppDelegate (`ios/Runner/AppDelegate/AppDelegate.swift`)

**Назначение:** Точка входа для iOS приложения, регистрация каналов связи.

**Ключевые функции:**
- Регистрация `FlutterMethodChannel`
- Регистрация `FlutterEventChannel` с кастомным `StreamHandler`
- Маршрутизация вызовов к `MultipeerTransportManager`
- Генерация уникального `deviceId` на основе `identifierForVendor`

#### 3.2 MultipeerTransportManager (`ios/Runner/Transport/MultipeerTransportManager.swift`)

**Назначение:** Обертка над Multipeer Connectivity Framework.

**Service Type:** `secure-mesh` (должен быть 1-15 символов, [a-z0-9-])

**Особенности:**
- Шифрование обязательно (`encryptionPreference: .required`)
- Автоматическое принятие входящих подключений
- Автоматическая отправка приглашений обнаруженным устройствам
- Преобразование `Data` → `[Int]` для передачи во Flutter

**Важные ограничения iOS:**
- Максимум 8 пиров в одной сессии
- Требуется явное разрешение пользователя при первом подключении
- Ограниченная фоновая работа (только при активном использовании)

## Интеграция с Flutter

### Пример использования в Dart коде:

```dart
import 'package:secure_mesh/services/native_transport_channel.dart';
import 'package:secure_mesh/services/crypto_service.dart';

class MeshTransportService {
  final NativeTransportChannel _channel = NativeTransportChannel();
  final CryptoService _crypto;

  MeshTransportService(this._crypto);

  Future<void> initialize(String deviceName, String deviceId) async {
    // Подписка на события
    _channel.eventStream.listen(_handleEvent);
    
    // Инициализация нативного транспорта
    await _channel.initialize(
      deviceName: deviceName,
      deviceId: deviceId,
    );
  }

  void _handleEvent(Map<String, dynamic> event) {
    switch (event['type']) {
      case 'peerDiscovered':
        print("Обнаружен пир: ${event['peerName']}");
        break;
        
      case 'messageReceived':
        final peerId = event['peerId'];
        final data = List<int>.from(event['data']);
        _processReceivedMessage(peerId, data);
        break;
        
      case 'connected':
        print("Подключено к: ${event['peerId']}");
        break;
    }
  }

  Future<void> sendMessage(String peerId, String message) async {
    // Шифруем сообщение
    final encrypted = await _crypto.encrypt(message);
    
    // Отправляем зашифрованные данные
    await _channel.sendToPeer(peerId, encrypted);
  }

  void _processReceivedMessage(String peerId, List<int> encryptedData) async {
    // Дешифруем сообщение
    final decrypted = await _crypto.decrypt(encryptedData);
    print("Получено от $peerId: $decrypted");
  }
}
```

## Настройка проекта

### Android

1. **Добавить зависимости в `android/app/build.gradle`:**
```gradle
dependencies {
    implementation 'com.google.android.gms:play-services-nearby:18.5.0'
    // ... другие зависимости
}
```

2. **Обновить `AndroidManifest.xml`:**
```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <!-- Разрешения -->
    <uses-permission android:name="android.permission.BLUETOOTH" />
    <uses-permission android:name="android.permission.BLUETOOTH_ADMIN" />
    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
    
    <!-- Для Android 12+ -->
    <uses-permission android:name="android.permission.BLUETOOTH_SCAN" />
    <uses-permission android:name="android.permission.BLUETOOTH_ADVERTISE" />
    <uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
    
    <application ...>
        <activity
            android:name=".MainActivity"
            android:exported="true"
            ...>
            <intent-filter>
                <action android:name="android.intent.action.MAIN"/>
                <category android:name="android.intent.category.LAUNCHER"/>
            </intent-filter>
        </activity>
    </application>
</manifest>
```

### iOS

1. **Добавить capabilities в Xcode:**
   - Открыть проект в Xcode
   - Выбрать target Runner
   - Вкладка "Signing & Capabilities"
   - Добавить "Multipeer Connectivity"

2. **Добавить описания в `Info.plist`:**
```xml
<key>NSLocalNetworkUsageDescription</key>
<string>Приложение использует локальную сеть для обмена сообщениями с nearby устройствами</string>

<key>NSBluetoothAlwaysUsageDescription</key>
<string>Приложение использует Bluetooth для обнаружения и подключения к nearby устройствам</string>

<key>NSBluetoothPeripheralUsageDescription</key>
<string>Приложение использует Bluetooth для обмена сообщениями с nearby устройствами</string>
```

3. **Убедиться, что `AppDelegate.swift` является точкой входа:**
   - Файл должен содержать `@UIApplicationMain`
   - Или использовать `main.swift` с явным созданием AppDelegate

## Тестирование

### Сценарии тестирования:

1. **Обнаружение устройств:**
   - Запустить приложение на двух устройствах
   - Проверить событие `peerDiscovered` на обоих устройствах
   - Убедиться, что устройства видят друг друга

2. **Подключение:**
   - После обнаружения должно произойти автоматическое подключение
   - Проверить событие `connected`
   - Проверить список подключенных пиров

3. **Отправка сообщений:**
   - Отправить тестовое сообщение
   - Проверить получение на другом устройстве
   - Убедиться, что данные совпадают

4. **Потеря соединения:**
   - Выйти из зоны действия
   - Проверить событие `peerLost` / `disconnected`
   - Вернуться в зону действия
   - Проверить автоматическое переподключение

### Отладка:

**Android:**
```bash
adb logcat | grep -E "(NearbyTransport|MainActivity)"
```

**iOS:**
```bash
# В Xcode: Product → Console
# Или через терминал:
tail -f ~/Library/Logs/CoreSimulator/<device_id>/system.log | grep MultipeerTransport
```

## Известные ограничения

### Android:
- Google Play Services требуются для работы Nearby API
- Фоновая работа ограничена в Android 10+
- Требуется разрешение на местоположение для BLE сканирования

### iOS:
- Максимум 8 одновременных подключений
- Требуется взаимодействие пользователя для первого подключения
- Ограниченная фоновая работа
- Service type должен быть уникальным и зарегистрированным

## Следующие шаги

1. ✅ Нативные транспортные модули реализованы
2. ⏳ Интеграция с `MeshService` для сквозной отправки сообщений
3. ⏳ Добавление persistent storage для офлайн очереди
4. ⏳ Реализация mesh-ретрансляции (store-and-forward)
5. ⏳ Добавление libp2p для интернет-транспорта
