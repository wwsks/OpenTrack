import 'package:flutter/material.dart';
import '../models/package.dart';

class PackageCard extends StatelessWidget {
  final Package package;
  final VoidCallback? onTap;
  final VoidCallback? onRefresh;

  const PackageCard({
    super.key,
    required this.package,
    this.onTap,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              _StatusIcon(status: package.status),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            package.companyName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        Text(
                          _statusText(package.status),
                          style: TextStyle(
                            color: _statusColor(package.status),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      package.trackingNumber,
                      style:
                          const TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                    if (package.remark != null &&
                        package.remark!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        package.remark!,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (package.lastContext.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        package.lastContext,
                        style: const TextStyle(fontSize: 13),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 2),
                    Text(
                      _formatTime(package.lastTime),
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              if (onRefresh != null)
                IconButton(
                  icon: const Icon(Icons.refresh, size: 20),
                  onPressed: onRefresh,
                  tooltip: '刷新',
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _statusText(String status) {
    switch (status) {
      case '0':
        return '在途';
      case '1':
        return '揽收';
      case '3':
        return '已签收';
      case '5':
        return '派件中';
      case '2':
        return '疑难';
      case '6':
        return '退回';
      default:
        return status;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case '0':
        return Colors.blue;
      case '1':
        return Colors.orange;
      case '3':
        return Colors.green;
      case '5':
        return Colors.purple;
      case '2':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
      return '今天 ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
    return '${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

class _StatusIcon extends StatelessWidget {
  final String status;
  const _StatusIcon({required this.status});

  @override
  Widget build(BuildContext context) {
    IconData icon;
    Color color;
    switch (status) {
      case '0':
        icon = Icons.local_shipping;
        color = Colors.blue;
      case '1':
        icon = Icons.inventory_2;
        color = Colors.orange;
      case '3':
        icon = Icons.check_circle;
        color = Colors.green;
      case '5':
        icon = Icons.delivery_dining;
        color = Colors.purple;
      case '2':
        icon = Icons.warning;
        color = Colors.red;
      default:
        icon = Icons.help_outline;
        color = Colors.grey;
    }
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: color, size: 24),
    );
  }
}
