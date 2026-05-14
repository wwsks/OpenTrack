import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/package.dart';
import '../../models/tracking_info.dart';
import '../../providers/package_provider.dart';

class DetailScreen extends ConsumerWidget {
  final Package package;
  final TrackingInfo? trackingInfo;

  const DetailScreen({super.key, required this.package, this.trackingInfo});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('快递详情'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              await ref
                  .read(allPackagesProvider.notifier)
                  .refreshSingle(package);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('已刷新')),
                );
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _InfoCard(package: package),
            const SizedBox(height: 16),
            if (trackingInfo != null)
              _TimelineCard(info: trackingInfo!)
            else
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final Package package;
  const _InfoCard({required this.package});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _infoRow('快递公司', package.companyName),
            _infoRow('快递单号', package.trackingNumber),
            _infoRow('当前状态', _statusText(package.status)),
            if (package.remark != null && package.remark!.isNotEmpty)
              _infoRow('物品备注', package.remark!),
            _infoRow('添加时间', _formatDate(package.addedTime)),
            _infoRow('更新时间', _formatDate(package.lastTime)),
          ],
        ),
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
            width: 80,
            child: Text(label,
                style: const TextStyle(color: Colors.grey, fontSize: 14)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 14)),
          ),
        ],
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
      case '8':
        return '清关';
      default:
        return status;
    }
  }

  String _formatDate(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

class _TimelineCard extends StatelessWidget {
  final TrackingInfo info;
  const _TimelineCard({required this.info});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('物流轨迹',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            if (info.data.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('暂无轨迹信息', style: TextStyle(color: Colors.grey)),
                ),
              )
            else
              ...info.data.asMap().entries.map((entry) {
                final i = entry.key;
                final event = entry.value;
                final isFirst = i == 0;
                final isLast = i == info.data.length - 1;
                return _TimelineItem(
                  context: event.context,
                  time: event.ftime,
                  isFirst: isFirst,
                  isLast: isLast,
                );
              }),
          ],
        ),
      ),
    );
  }
}

class _TimelineItem extends StatelessWidget {
  final String context;
  final String time;
  final bool isFirst;
  final bool isLast;

  const _TimelineItem({
    required this.context,
    required this.time,
    required this.isFirst,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final color = isFirst
        ? Theme.of(context).colorScheme.primary
        : Colors.grey;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 24,
            child: Column(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color,
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: Colors.grey.shade300,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    this.context,
                    style: TextStyle(
                      fontSize: 14,
                      color: isFirst ? null : Colors.grey.shade700,
                      fontWeight:
                          isFirst ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(time,
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey.shade500)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
