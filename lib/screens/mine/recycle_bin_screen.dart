import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/settings_provider.dart';

class RecycleBinScreen extends ConsumerWidget {
  const RecycleBinScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deleted = ref.watch(deletedPackagesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('回收站'),
        actions: [
          if (deleted.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep),
              tooltip: '清空回收站',
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('清空回收站'),
                    content: const Text('确定要永久删除所有快递记录吗？此操作不可恢复。'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('取消'),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          ref.read(deletedPackagesProvider.notifier).clearAll();
                        },
                        child: const Text('清空',
                            style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
      body: deleted.isEmpty
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.delete_outline, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('回收站为空', style: TextStyle(color: Colors.grey, fontSize: 16)),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: deleted.length,
              itemBuilder: (context, index) {
                final pkg = deleted[index];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: ListTile(
                    leading: const Icon(Icons.delete_outline, color: Colors.grey),
                    title: Text(pkg.companyName,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(pkg.trackingNumber),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.restore, color: Colors.green),
                          tooltip: '恢复',
                          onPressed: () {
                            ref
                                .read(deletedPackagesProvider.notifier)
                                .restore(pkg.id);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('已恢复')),
                            );
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_forever, color: Colors.red),
                          tooltip: '永久删除',
                          onPressed: () {
                            ref
                                .read(deletedPackagesProvider.notifier)
                                .permanentlyDelete(pkg.id);
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
