import 'package:flutter/material.dart';

import '../../config/constants.dart';
import '../../ui/theme/app_theme.dart';

/// Индикатор состояния сети
class ConnectionIndicator extends StatelessWidget {
  final ConnectionStatus status;
  final int peerCount;
  final String? message;

  const ConnectionIndicator({
    super.key,
    this.status = ConnectionStatus.pending,
    this.peerCount = 0,
    this.message,
  });

  @override
  Widget build(BuildContext context) {
    final color = _getStatusColor(status);
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        border: Border(
          bottom: BorderSide(
            color: color.withOpacity(0.3),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // Индикатор статуса
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.5),
                  blurRadius: 4,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          
          // Текст статуса
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  status.label,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: color,
                    fontSize: 14,
                  ),
                ),
                if (message != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    message!,
                    style: TextStyle(
                      fontSize: 12,
                      color: color.withOpacity(0.8),
                    ),
                  ),
                ],
                if (peerCount > 0) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Пиров рядом: $peerCount',
                    style: TextStyle(
                      fontSize: 12,
                      color: color.withOpacity(0.8),
                    ),
                  ),
                ],
              ],
            ),
          ),
          
          // Кнопка информации
          IconButton(
            icon: const Icon(Icons.info_outline, size: 20),
            onPressed: () {
              _showNetworkInfo(context);
            },
            color: color,
          ),
        ],
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

  void _showNetworkInfo(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: _getStatusColor(status),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Статус сети',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildInfoRow('Текущий статус', status.label),
            _buildInfoRow('Пиров рядом', '$peerCount'),
            _buildInfoRow(
              'Тип соединения',
              status == ConnectionStatus.direct
                  ? 'Прямое (BLE/Wi-Fi)'
                  : status == ConnectionStatus.meshRelay
                      ? 'Через другие устройства'
                      : status == ConnectionStatus.pending
                          ? 'Ожидание подключения'
                          : 'Нет соединения',
            ),
            const SizedBox(height: 16),
            const Text(
              'Зеленый индикатор означает прямое соединение с получателем.\n'
              'Желтый — сообщение будет доставлено через других пользователей.\n'
              'Серый — сообщение сохранено и будет отправлено при появлении соединения.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 14),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

/// Анимированный индикатор активности сети
class NetworkActivityIndicator extends StatefulWidget {
  final bool isActive;

  const NetworkActivityIndicator({
    super.key,
    required this.isActive,
  });

  @override
  State<NetworkActivityIndicator> createState() =>
      _NetworkActivityIndicatorState();
}

class _NetworkActivityIndicatorState extends State<NetworkActivityIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    if (widget.isActive) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(NetworkActivityIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.isActive && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          size: const Size(20, 20),
          painter: _WavePainter(_controller.value),
        );
      },
    );
  }
}

class _WavePainter extends CustomPainter {
  final double animation;

  _WavePainter(this.animation);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppTheme.statusDirect.withOpacity(0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    for (int i = 0; i < 3; i++) {
      final offset = (animation * 3 - i) % 3;
      final radius = size.width / 2 * (offset / 3);
      
      if (radius > 0) {
        canvas.drawCircle(
          Offset(size.width / 2, size.height / 2),
          radius,
          paint..opacity = (1 - offset / 3) * 0.6,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_WavePainter oldDelegate) => true;
}
