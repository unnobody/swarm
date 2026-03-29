import 'package:hive/hive.dart';

/// Сервис для хранения легких настроек приложения на базе Hive
/// 
/// Используется для:
/// - Пользовательских предпочтений
/// - Настроек приватности
/// - Режимов работы (экономия батареи, приватность)
/// - Кэширования временных данных
class SettingsService {
  static late Box _settingsBox;
  static late Box _cacheBox;
  static bool _isInitialized = false;

  // Ключи настроек
  static const String _keyUserId = 'user_id';
  static const String _keyDisplayName = 'display_name';
  static const String _keyPrivacyMode = 'privacy_mode';
  static const String _keyBatterySaverMode = 'battery_saver_mode';
  static const String _keyAutoRelay = 'auto_relay';
  static const String _keyNotificationsEnabled = 'notifications_enabled';
  static const String _keyTheme = 'theme';
  static const String _keyLanguage = 'language';
  static const String _keyLastBackup = 'last_backup';
  
  // Ключи кэша
  static const String _keyLastSyncTime = 'last_sync_time';
  static const String _keyNearbyPeers = 'nearby_peers';
  static const String _keyNetworkStats = 'network_stats';

  /// Инициализация хранилища настроек
  static Future<void> initialize() async {
    if (_isInitialized) return;

    // Инициализация Hive
    await Hive.initFlutter();
    
    // Открытие боксов
    _settingsBox = await Hive.openBox('settings');
    _cacheBox = await Hive.openBox('cache');
    
    _isInitialized = true;
    print('SettingsService initialized');
  }

  /// Проверка инициализации
  static void ensureInitialized() {
    if (!_isInitialized) {
      throw Exception('SettingsService not initialized. Call initialize() first.');
    }
  }

  // ==================== Настройки пользователя ====================

  /// Получить ID пользователя
  static String? getUserId() {
    ensureInitialized();
    return _settingsBox.get(_keyUserId);
  }

  /// Сохранить ID пользователя
  static Future<void> setUserId(String userId) async {
    ensureInitialized();
    await _settingsBox.put(_keyUserId, userId);
  }

  /// Получить отображаемое имя
  static String? getDisplayName() {
    ensureInitialized();
    return _settingsBox.get(_keyDisplayName);
  }

  /// Сохранить отображаемое имя
  static Future<void> setDisplayName(String name) async {
    ensureInitialized();
    await _settingsBox.put(_keyDisplayName, name);
  }

  // ==================== Настройки приватности ====================

  /// Режим приватности (true = максимальная приватность с ретрансляцией)
  static bool getPrivacyMode() {
    ensureInitialized();
    return _settingsBox.get(_keyPrivacyMode, defaultValue: false);
  }

  /// Установить режим приватности
  static Future<void> setPrivacyMode(bool enabled) async {
    ensureInitialized();
    await _settingsBox.put(_keyPrivacyMode, enabled);
  }

  /// Режим экономии батареи (true = только свои сообщения)
  static bool getBatterySaverMode() {
    ensureInitialized();
    return _settingsBox.get(_keyBatterySaverMode, defaultValue: false);
  }

  /// Установить режим экономии батареи
  static Future<void> setBatterySaverMode(bool enabled) async {
    ensureInitialized();
    await _settingsBox.put(_keyBatterySaverMode, enabled);
  }

  /// Автоматическая ретрансляция чужих сообщений
  static bool getAutoRelay() {
    ensureInitialized();
    return _settingsBox.get(_keyAutoRelay, defaultValue: true);
  }

  /// Установить автоматическую ретрансляцию
  static Future<void> setAutoRelay(bool enabled) async {
    ensureInitialized();
    await _settingsBox.put(_keyAutoRelay, enabled);
  }

  // ==================== Настройки уведомлений ====================

  /// Уведомления включены
  static bool getNotificationsEnabled() {
    ensureInitialized();
    return _settingsBox.get(_keyNotificationsEnabled, defaultValue: true);
  }

  /// Установить состояние уведомлений
  static Future<void> setNotificationsEnabled(bool enabled) async {
    ensureInitialized();
    await _settingsBox.put(_keyNotificationsEnabled, enabled);
  }

  // ==================== Настройки UI ====================

  /// Тема приложения (light, dark, system)
  static String getTheme() {
    ensureInitialized();
    return _settingsBox.get(_keyTheme, defaultValue: 'system');
  }

  /// Установить тему
  static Future<void> setTheme(String theme) async {
    ensureInitialized();
    await _settingsBox.put(_keyTheme, theme);
  }

  /// Язык приложения
  static String getLanguage() {
    ensureInitialized();
    return _settingsBox.get(_keyLanguage, defaultValue: 'ru');
  }

  /// Установить язык
  static Future<void> setLanguage(String language) async {
    ensureInitialized();
    await _settingsBox.put(_keyLanguage, language);
  }

  // ==================== Настройки синхронизации ====================

  /// Время последней синхронизации
  static DateTime? getLastSyncTime() {
    ensureInitialized();
    final timestamp = _cacheBox.get(_keyLastSyncTime);
    return timestamp != null ? DateTime.fromMillisecondsSinceEpoch(timestamp) : null;
  }

  /// Установить время последней синхронизации
  static Future<void> setLastSyncTime(DateTime time) async {
    ensureInitialized();
    await _cacheBox.put(_keyLastSyncTime, time.millisecondsSinceEpoch);
  }

  /// Время последнего бэкапа
  static DateTime? getLastBackup() {
    ensureInitialized();
    final timestamp = _settingsBox.get(_keyLastBackup);
    return timestamp != null ? DateTime.fromMillisecondsSinceEpoch(timestamp) : null;
  }

  /// Установить время последнего бэкапа
  static Future<void> setLastBackup(DateTime time) async {
    ensureInitialized();
    await _settingsBox.put(_keyLastBackup, time.millisecondsSinceEpoch);
  }

  // ==================== Кэш nearby-пиров ====================

  /// Получить список nearby-пиров из кэша
  static List<String> getNearbyPeers() {
    ensureInitialized();
    final peers = _cacheBox.get(_keyNearbyPeers, defaultValue: <String>[]);
    return List<String>.from(peers);
  }

  /// Сохранить список nearby-пиров в кэш
  static Future<void> setNearbyPeers(List<String> peerIds) async {
    ensureInitialized();
    await _cacheBox.put(_keyNearbyPeers, peerIds);
  }

  /// Очистить кэш nearby-пиров
  static Future<void> clearNearbyPeersCache() async {
    ensureInitialized();
    await _cacheBox.delete(_keyNearbyPeers);
  }

  // ==================== Статистика сети ====================

  /// Получить статистику сети из кэша
  static Map<String, dynamic>? getNetworkStats() {
    ensureInitialized();
    final stats = _cacheBox.get(_keyNetworkStats);
    return stats != null ? Map<String, dynamic>.from(stats) : null;
  }

  /// Сохранить статистику сети в кэш
  static Future<void> setNetworkStats(Map<String, dynamic> stats) async {
    ensureInitialized();
    await _cacheBox.put(_keyNetworkStats, stats);
  }

  /// Очистить кэш статистики
  static Future<void> clearNetworkStatsCache() async {
    ensureInitialized();
    await _cacheBox.delete(_keyNetworkStats);
  }

  // ==================== Общие методы ====================

  /// Получить все настройки
  static Map<String, dynamic> getAllSettings() {
    ensureInitialized();
    return Map<String, dynamic>.from(_settingsBox.toMap());
  }

  /// Получить произвольное значение
  static T? getValue<T>(String key, {T? defaultValue}) {
    ensureInitialized();
    return _settingsBox.get(key, defaultValue: defaultValue) as T?;
  }

  /// Сохранить произвольное значение
  static Future<void> setValue<T>(String key, T value) async {
    ensureInitialized();
    await _settingsBox.put(key, value);
  }

  /// Получить произвольное значение из кэша
  static T? getCachedValue<T>(String key, {T? defaultValue}) {
    ensureInitialized();
    return _cacheBox.get(key, defaultValue: defaultValue) as T?;
  }

  /// Сохранить произвольное значение в кэш
  static Future<void> setCachedValue<T>(String key, T value) async {
    ensureInitialized();
    await _cacheBox.put(key, value);
  }

  /// Очистить весь кэш
  static Future<void> clearCache() async {
    ensureInitialized();
    await _cacheBox.clear();
  }

  /// Сбросить все настройки к значениям по умолчанию
  static Future<void> resetSettings() async {
    ensureInitialized();
    await _settingsBox.clear();
    
    // Восстановить значения по умолчанию
    await setPrivacyMode(false);
    await setBatterySaverMode(false);
    await setAutoRelay(true);
    await setNotificationsEnabled(true);
    await setTheme('system');
    await setLanguage('ru');
  }

  /// Закрыть хранилище
  static Future<void> close() async {
    if (_isInitialized) {
      await _settingsBox.close();
      await _cacheBox.close();
      _isInitialized = false;
    }
  }

  /// Экспорт настроек (для бэкапа)
  static Future<Map<String, dynamic>> exportSettings() async {
    ensureInitialized();
    return Map<String, dynamic>.from(_settingsBox.toMap());
  }

  /// Импорт настроек (из бэкапа)
  static Future<void> importSettings(Map<String, dynamic> settings) async {
    ensureInitialized();
    await _settingsBox.clear();
    for (final entry in settings.entries) {
      await _settingsBox.put(entry.key, entry.value);
    }
  }
}
