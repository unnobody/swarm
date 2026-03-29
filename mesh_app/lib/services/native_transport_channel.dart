import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/peer_model.dart';
import '../models/message_model.dart';

/// События от нативного транспортного слоя
enum NativeTransportEvent {
  peerDiscovered,
  peerLost,
  messageReceived,
  connectionStateChanged,
  error,
}

/// Обработчик нативных транспортных каналов (Android Nearby / iOS Multipeer)
class NativeTransportChannel {
  static const MethodChannel _channel = MethodChannel('secure_mesh/transport');
  static const EventChannel _eventChannel = EventChannel('secure_mesh/transport_events');

  final StreamController<Map<String, dynamic>> _eventController = 
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get eventStream => _eventController.stream;

  NativeTransportChannel() {
    _setupListener();
  }

  void _setupListener() {
    _eventChannel.receiveBroadcastStream().listen((dynamic event) {
      if (event is Map) {
        _eventController.add(Map<String, dynamic>.from(event));
      } else if (event is String) {
        // Попытка распарсить строку как JSON если пришло так
        try {
          final decoded = jsonDecode(event);
          if (decoded is Map) {
            _eventController.add(decoded);
          }
        } catch (_) {}
      }
    });
  }

  /// Инициализация транспорта (запуск сканирования/рекламы)
  Future<void> initialize({
    required String deviceName,
    required String deviceId,
  }) async {
    await _channel.invokeMethod('initialize', {
      'deviceName': deviceName,
      'deviceId': deviceId,
    });
  }

  /// Начать поиск соседей
  Future<void> startDiscovery() async {
    await _channel.invokeMethod('startDiscovery');
  }

  /// Остановить поиск
  Future<void> stopDiscovery() async {
    await _channel.invokeMethod('stopDiscovery');
  }

  /// Начать рекламу себя для других
  Future<void> startAdvertising() async {
    await _channel.invokeMethod('startAdvertising');
  }

  /// Остановить рекламу
  Future<void> stopAdvertising() async {
    await _channel.invokeMethod('stopAdvertising');
  }

  /// Запрос на подключение к пиру
  Future<void> connectToPeer(String peerId) async {
    await _channel.invokeMethod('connectToPeer', {'peerId': peerId});
  }

  /// Отключение от пира
  Future<void> disconnectFromPeer(String peerId) async {
    await _channel.invokeMethod('disconnectFromPeer', {'peerId': peerId});
  }

  /// Отправка зашифрованных данных пиру
  Future<bool> sendToPeer(String peerId, List<int> data) async {
    try {
      final result = await _channel.invokeMethod<bool>('sendToPeer', {
        'peerId': peerId,
        'data': data, // Uint8List автоматически конвертируется
      });
      return result ?? false;
    } catch (e) {
      print('Error sending to peer: $e');
      return false;
    }
  }

  /// Обработка входящего события (для отладки)
  void dispose() {
    _eventController.close();
  }
}
