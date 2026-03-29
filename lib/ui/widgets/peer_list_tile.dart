import 'package:flutter/material.dart';

import '../../config/constants.dart';
import '../../ui/theme/app_theme.dart';

/// Элемент списка пиров (контактов)
class PeerListTile extends StatelessWidget {
  final String peerId;
  final ConnectionStatus status;
  final DateTime lastSeen;
  final bool isRelay;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const PeerListTile({
    super.key,
    required this.peerId,
    required this.status,
    required this.lastSeen,
    this.isRelay = false,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final color = _getStatusColor(status);
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: Stack(
          children: [
            CircleAvatar(
              backgroundColor: color.withOpacity(0.2),
              child: Icon(
                isRelay ? Icons.hub : Icons.person,
                color: color,
              ),
            ),
            // Индикатор статуса в углу
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    width: 2,
                  ),
                ),
              ),
            ),
          ],
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                _formatPeerId(peerId),
                style: const TextStyle(fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isRelay) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Ретранслятор',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.blue.shade700,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  _getStatusIcon(status),
                  size: 14,
                  color: color,
                ),
                const SizedBox(width: 4),
                Text(
                  status.label,
                  style: TextStyle(
                    fontSize: 12,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              'Был(а) ${_formatLastSeen(lastSeen)}',
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.more_vert),
          onPressed: () {
            _showPeerMenu(context);
          },
        ),
        onTap: onTap,
        onLongPress: onLongPress,
      ),
    );
  }

  Color _getStatusColor(ConnectionStatus status) {
    switch (status) {
      case ConnectionStatus.direct:
        return AppTheme.statusDirect;
      case ConnectionStatus.meshRelay:
        return AppTheme.statusMeshRelay;
      case ConnectionStatus.pending:
        return AppTheme.statusPending;
      case ConnectionStatus.disconnected:
        return AppTheme.statusDisconnected;
    }
  }

  IconData _getStatusIcon(ConnectionStatus status) {
    switch (status) {
      case ConnectionStatus.direct:
        return Icons.bluetooth_connected;
      case ConnectionStatus.meshRelay:
        return Icons.wifi_tethering;
      case ConnectionStatus.pending:
        return Icons.schedule;
      case ConnectionStatus.disconnected:
        return Icons.bluetooth_disabled;
    }
  }

  String _formatPeerId(String id) {
    if (id.length <= 8) return id;
    return '${id.substring(0, 8)}...${id.substring(id.length - 4)}';
  }

  String _formatLastSeen(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'только что';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} мин. назад';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} ч. назад';
    } else {
      return '${difference.inDays} дн. назад';
    }
  }

  void _showPeerMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.qr_code),
              title: const Text('Показать QR-код'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Показать QR-код пира
              },
            ),
            ListTile(
              leading: const Icon(Icons.share),
              title: const Text('Поделиться контактом'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Поделиться контактом
              },
            ),
            if (status != ConnectionStatus.disconnected) ...[
              ListTile(
                leading: const Icon(Icons.send),
                title: const Text('Отправить сообщение'),
                onTap: () {
                  Navigator.pop(context);
                  // TODO: Перейти к чату
                },
              ),
            ],
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('Информация'),
              onTap: () {
                Navigator.pop(context);
                _showPeerInfo(context);
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.block, color: Colors.red),
              title: const Text('Заблокировать', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                // TODO: Заблокировать пира
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showPeerInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Информация о пире'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _infoRow('ID', peerId),
            _infoRow('Статус', status.label),
            _infoRow('Был(а)', _formatLastSeen(lastSeen)),
            _infoRow('Ретранслятор', isRelay ? 'Да' : 'Нет'),
            const SizedBox(height: 16),
            const Text(
              'Публичный ключ:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            SelectableText(
              '0x${peerId.codeUnits.map((e) => e.toRadixString(16).padLeft(2, '0')).join()}',
              style: const TextStyle(fontSize: 10, fontFamily: 'monospace'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Закрыть'),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

/// Виджет для отображения статуса доставки сообщения
class MessageDeliveryStatus extends StatelessWidget {
  final ConnectionStatus status;
  final bool isRead;

  const MessageDeliveryStatus({
    super.key,
    required this.status,
    this.isRead = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = _getStatusColor(status);
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          _getStatusIcon(),
          size: 16,
          color: color,
        ),
        if (isRead) ...[
          const SizedBox(width: 2),
          Icon(
            Icons.check,
            size: 12,
            color: color,
          ),
        ],
      ],
    );
  }

  Color _getStatusColor(ConnectionStatus status) {
    switch (status) {
      case ConnectionStatus.direct:
        return AppTheme.statusDirect;
      case ConnectionStatus.meshRelay:
        return AppTheme.statusMeshRelay;
      case ConnectionStatus.pending:
        return AppTheme.statusPending;
      case ConnectionStatus.disconnected:
        return AppTheme.statusDisconnected;
    }
  }

  IconData _getStatusIcon() {
    if (isRead) {
      return Icons.done_all;
    }
    
    switch (status) {
      case ConnectionStatus.direct:
        return Icons.check_circle;
      case ConnectionStatus.meshRelay:
        return Icons.route;
      case ConnectionStatus.pending:
        return Icons.hourglass_empty;
      case ConnectionStatus.disconnected:
        return Icons.error;
    }
  }
}
