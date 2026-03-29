import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../widgets/connection_indicator.dart';
import '../widgets/peer_list_tile.dart';
import '../../config/constants.dart';

/// Главный экран приложения
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: const [
          _ChatsTab(),
          _ContactsTab(),
          _SettingsTab(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline),
            selectedIcon: Icon(Icons.chat_bubble),
            label: 'Чаты',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: 'Контакты',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Настройки',
          ),
        ],
      ),
    );
  }
}

/// Вкладка чатов
class _ChatsTab extends ConsumerWidget {
  const _ChatsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        // Индикатор состояния сети
        const ConnectionIndicator(),
        
        // Список чатов
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: 0, // TODO: Заменить на реальные данные
            itemBuilder: (context, index) {
              return ListTile(
                leading: const CircleAvatar(
                  child: Icon(Icons.person),
                ),
                title: Text('Чат $index'),
                subtitle: Text('Последнее сообщение...'),
                onTap: () {
                  // Навигация к экрану чата
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Вкладка контактов
class _ContactsTab extends ConsumerWidget {
  const _ContactsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Text(
                'Контакты',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.qr_code_scanner),
                onPressed: () {
                  // Сканирование QR-кода для добавления контакта
                },
              ),
              IconButton(
                icon: const Icon(Icons.qr_code),
                onPressed: () {
                  // Показать свой QR-код
                },
              ),
            ],
          ),
        ),
        
        // Список пиров
        Expanded(
          child: ListView.builder(
            itemCount: 0, // TODO: Заменить на реальные данные
            itemBuilder: (context, index) {
              return PeerListTile(
                peerId: 'peer_$index',
                status: index % 2 == 0 
                    ? ConnectionStatus.direct 
                    : ConnectionStatus.meshRelay,
                lastSeen: DateTime.now(),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Вкладка настроек
class _SettingsTab extends ConsumerStatefulWidget {
  const _SettingsTab();

  @override
  ConsumerState<_SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends ConsumerState<_SettingsTab> {
  OperationMode _selectedMode = OperationMode.standard;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Режим работы',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        
        // Выбор режима работы
        ...OperationMode.values.map((mode) {
          return Card(
            child: RadioListTile<OperationMode>(
              title: Text(mode.name),
              subtitle: Text(mode.description),
              secondary: _buildBatteryIndicator(mode.batteryImpact),
              value: mode,
              groupValue: _selectedMode,
              onChanged: (value) {
                setState(() {
                  _selectedMode = value!;
                });
                // TODO: Сохранить выбор и применить в Rust core
              },
            ),
          );
        }),
        
        const Divider(height: 32),
        
        // Дополнительные настройки
        SwitchListTile(
          title: const Text('Ретрансляция сообщений'),
          subtitle: const Text('Помогать передавать сообщения других пользователей'),
          value: _selectedMode == OperationMode.maxPrivacy,
          onChanged: (value) {
            setState(() {
              _selectedMode = value 
                  ? OperationMode.maxPrivacy 
                  : OperationMode.standard;
            });
          },
        ),
        
        SwitchListTile(
          title: const Text('Только при подключении к Wi-Fi'),
          subtitle: const Text('Синхронизация только через Wi-Fi'),
          value: false,
          onChanged: (value) {
            // TODO: Реализовать
          },
        ),
        
        const Divider(height: 32),
        
        // Информация о приложении
        const ListTile(
          title: Text('Версия приложения'),
          subtitle: Text(AppConstants.appVersion),
          trailing: Icon(Icons.info_outline),
        ),
      ],
    );
  }
  
  Widget _buildBatteryIndicator(int level) {
    IconData icon;
    Color color;
    
    switch (level) {
      case 0:
        icon = Icons.battery_std;
        color = Colors.green;
        break;
      case 1:
        icon = Icons.battery_3_bar;
        color = Colors.lightGreen;
        break;
      case 2:
        icon = Icons.battery_5_bar;
        color = Colors.orange;
        break;
      case 3:
        icon = Icons.battery_full;
        color = Colors.red;
        break;
      default:
        icon = Icons.battery_unknown;
        color = Colors.grey;
    }
    
    return Icon(icon, color: color);
  }
}

// Заглушки для экранов
class ChatScreen extends StatelessWidget {
  final String chatId;
  const ChatScreen({super.key, required this.chatId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Чат $chatId'),
      ),
      body: const Center(
        child: Text('Экран чата'),
      ),
    );
  }
}

class ContactsScreen extends StatelessWidget {
  const ContactsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text('Экран контактов'),
      ),
    );
  }
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text('Экран настроек'),
      ),
    );
  }
}
