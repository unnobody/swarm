# Mesh Secure — Децентрализованный мессенджер с Mesh-сетью

Приложение для безопасного общения через Mesh-сети с поддержкой работы без интернета.

## 📋 Обзор

**Mesh Secure** — это кроссплатформенное приложение (iOS/Android), которое использует децентрализованную архитектуру для обмена сообщениями:

- 🔒 **Сквозное шифрование** на основе libsodium
- 📡 **Работа без интернета** через Bluetooth и Wi-Fi Direct
- 🌐 **Mesh-ретрансляция** сообщений через другие устройства
- 🎨 **Интуитивный UI** на Flutter с визуализацией статуса сети

## 🏗 Архитектура

```
┌─────────────────────────────────────────────────────┐
│                   Flutter UI Layer                  │
│  (main.dart, screens/, widgets/)                    │
├─────────────────────────────────────────────────────┤
│              Dart Service Layer                     │
│  (crypto_service.dart, identity_service.dart)       │
├─────────────────────────────────────────────────────┤
│              FFI Bridge (flutter_rust_bridge)       │
├─────────────────────────────────────────────────────┤
│                Rust Core Layer                      │
│  (mesh_core/src/lib.rs)                             │
│  • Криптография (libsodium)                         │
│  • Синхронизация данных (automerge)                 │
│  • Сетевые протоколы (libp2p)                       │
└─────────────────────────────────────────────────────┘
```
│  ┌────────────────────┬──────────────────────────┐  │
│  │ Android Nearby API │ iOS Multipeer Framework  │  │
│  └────────────────────┴──────────────────────────┘  │
└─────────────────────────────────────────────────────┘
```

## Технологический стек

- **UI**: Flutter 3.x (Dart)
- **Core Logic**: Rust
- **Crypto**: libsodium (через Rust)
- **Data Sync**: Automerge (CRDT)
- **Internet Transport**: libp2p
- **Local Transport**: 
  - Android: Google Nearby Connections API
  - iOS: Multipeer Connectivity Framework

## Структура проекта

```
secure_mesh_app/
├── rust_core/              # Rust код (криптография, синхронизация)
│   ├── src/
│   │   ├── crypto.rs       # Шифрование (libsodium)
│   │   ├── sync.rs         # CRDT синхронизация (Automerge)
│   │   ├── transport.rs    # P2P транспорт (libp2p)
│   │   └── lib.rs          # Точки входа для Flutter
│   ├── Cargo.toml
│   └── build.rs
├── lib/                    # Flutter Dart код
│   ├── main.dart
│   ├── app.dart
│   ├── config/
│   │   └── constants.dart
│   ├── models/
│   │   ├── message.dart
│   │   ├── peer.dart
│   │   └── network_status.dart
│   ├── services/
│   │   ├── crypto_service.dart
│   │   ├── sync_service.dart
│   │   └── transport_service.dart
│   ├── stores/
│   │   └── app_store.dart
│   ├── ui/
│   │   ├── screens/
│   │   │   ├── home_screen.dart
│   │   │   ├── chat_screen.dart
│   │   │   ├── contacts_screen.dart
│   │   │   └── settings_screen.dart
│   │   ├── widgets/
│   │   │   ├── message_bubble.dart
│   │   │   ├── connection_indicator.dart
│   │   │   ├── peer_list_tile.dart
│   │   │   └── network_map.dart
│   │   └── theme/
│   │       └── app_theme.dart
│   └── bridges/
│       └── rust_bridge_generated.dart
├── android/                # Android специфичный код
│   └── app/src/main/kotlin/.../NearbyService.kt
├── ios/                    # iOS специфичный код
│   └── Runner/MultipeerService.swift
├── pubspec.yaml
├── flutter_rust_bridge.yaml
└── README.md
```

## Ключевые особенности

### 🔒 Безопасность
- End-to-end шифрование на основе Signal Protocol
- Хранение ключей в Secure Enclave (iOS) / Keystore (Android)
- Noise Protocol для установления соединения
- Децентрализованная идентификация (DID)

### 📡 Mesh-сеть
- Работа без интернета через BLE/Wi-Fi Direct
- Автоматическая ретрансляция сообщений через соседние узлы
- Офлайн-синхронизация с разрешением конфликтов (CRDT)

### 💎 UX/UI
- Визуализация статуса соединения (прямое/через узлы/ожидание)
- Индикаторы пути доставки сообщений
- Карта сети с анонимными nearby-узлами
- Режимы энергосбережения

## Быстрый старт

### Требования
- Flutter SDK 3.x
- Rust toolchain (rustup)
- Flutter Rust Bridge (`cargo install flutter_rust_bridge_codegen`)

### Установка

```bash
# 1. Клонируйте репозиторий
git clone <repository-url>
cd secure_mesh_app

# 2. Установите зависимости Flutter
flutter pub get

# 3. Сгенерируйте Rust bridge
flutter_rust_bridge_codegen generate

# 4. Запустите приложение
flutter run
```

## Режимы работы

| Режим | Описание | Энергопотребление |
|-------|----------|-------------------|
| 🟢 Максимальная приватность | Ретрансляция чужих сообщений | Высокое |
| 🟡 Стандартный | Только свои сообщения + прием | Среднее |
| 🔵 Экономия | Минимальная активность BLE | Низкое |
| ⚪ Только интернет | Без локальной сети | Минимальное |

## Лицензия

MIT License - см. файл LICENSE

## Предупреждения

⚠️ **Ограничения iOS**: Apple ограничивает фоновую работу Mesh-сетей. На iOS приложение использует Multipeer Connectivity для прямых соединений и Push-уведомления для активации.

⚠️ **Лицензии**: Проект использует библиотеки с лицензиями Apache 2.0 и MIT. При использовании кода из проектов с GPL (например, Briar) ваше приложение должно быть открытым.