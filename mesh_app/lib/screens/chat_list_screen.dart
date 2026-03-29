import 'package:flutter/material.dart';
import 'chat_screen.dart';

class ChatListScreen extends StatelessWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Чаты'),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: () {
              // Scan QR to add contact
              _showAddContactDialog(context);
            },
            tooltip: 'Добавить контакт',
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {
              // Open settings
            },
            tooltip: 'Настройки',
          ),
        ],
      ),
      body: Column(
        children: [
          // Network status banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.teal.shade50,
            child: Row(
              children: [
                Icon(
                  Icons.wifi_tethering,
                  size: 20,
                  color: Colors.teal.shade700,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Mesh-сеть активна • 3 устройства рядом',
                    style: TextStyle(
                      color: Colors.teal.shade700,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: 0, // No chats yet
              itemBuilder: (context, index) {
                return const ListTile();
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          _showNewChatDialog(context);
        },
        icon: const Icon(Icons.message),
        label: const Text('Новый чат'),
      ),
    );
  }

  void _showAddContactDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Добавить контакт'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Отсканируйте QR-код контакта'),
            const SizedBox(height: 16),
            Container(
              height: 200,
              width: 200,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Center(
                child: Icon(Icons.qr_code, size: 100),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Или поделитесь своим QR-кодом',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Show own QR code
            },
            child: const Text('Мой QR'),
          ),
        ],
      ),
    );
  }

  void _showNewChatDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Новый чат'),
        content: const Text('У вас пока нет контактов. Добавьте контакт через QR-код.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
