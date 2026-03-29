/// Константы приложения
class AppConstants {
  static const String appName = 'Secure Mesh';
  static const String appVersion = '1.0.0';
  
  // Режимы работы
  static const String modeMaxPrivacy = 'max_privacy';
  static const String modeStandard = 'standard';
  static const String modePowerSave = 'power_save';
  static const String modeInternetOnly = 'internet_only';
  
  // Статусы соединения
  static const String statusDirect = 'direct';
  static const String statusMeshRelay = 'mesh_relay';
  static const String statusPending = 'pending';
  static const String statusDisconnected = 'disconnected';
  
  // Таймауты
  static const Duration connectionTimeout = Duration(seconds: 30);
  static const Duration messageRetryTimeout = Duration(seconds: 5);
  static const Duration peerDiscoveryInterval = Duration(seconds: 10);
  
  // Лимиты
  static const int maxMessageLength = 10000;
  static const int maxPendingMessages = 1000;
  static const int maxPeers = 50;
  
  // Цвета статусов
  static const int colorDirect = 0xFF4CAF50; // Зеленый
  static const int colorMeshRelay = 0xFFFFC107; // Желтый
  static const int colorPending = 0xFF9E9E9E; // Серый
  static const int colorDisconnected = 0xFFF44336; // Красный
}

/// Перечисление режимов работы
enum OperationMode {
  maxPrivacy,
  standard,
  powerSave,
  internetOnly,
}

extension OperationModeExtension on OperationMode {
  String get name {
    switch (this) {
      case OperationMode.maxPrivacy:
        return 'Максимальная приватность';
      case OperationMode.standard:
        return 'Стандартный';
      case OperationMode.powerSave:
        return 'Экономия';
      case OperationMode.internetOnly:
        return 'Только интернет';
    }
  }

  String get description {
    switch (this) {
      case OperationMode.maxPrivacy:
        return 'Ретрансляция чужих сообщений';
      case OperationMode.standard:
        return 'Только свои сообщения + прием';
      case OperationMode.powerSave:
        return 'Минимальная активность BLE';
      case OperationMode.internetOnly:
        return 'Без локальной сети';
    }
  }

  int get batteryImpact {
    switch (this) {
      case OperationMode.maxPrivacy:
        return 3; // Высокое
      case OperationMode.standard:
        return 2; // Среднее
      case OperationMode.powerSave:
        return 1; // Низкое
      case OperationMode.internetOnly:
        return 0; // Минимальное
    }
  }
}

/// Статус соединения
enum ConnectionStatus {
  direct,
  meshRelay,
  pending,
  disconnected,
}

extension ConnectionStatusExtension on ConnectionStatus {
  String get label {
    switch (this) {
      case ConnectionStatus.direct:
        return 'Прямое';
      case ConnectionStatus.meshRelay:
        return 'Через узлы';
      case ConnectionStatus.pending:
        return 'Ожидание';
      case ConnectionStatus.disconnected:
        return 'Нет связи';
    }
  }

  String get emoji {
    switch (this) {
      case ConnectionStatus.direct:
        return '🟢';
      case ConnectionStatus.meshRelay:
        return '🟡';
      case ConnectionStatus.pending:
        return '⚪';
      case ConnectionStatus.disconnected:
        return '🔴';
    }
  }
}
