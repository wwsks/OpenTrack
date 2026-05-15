import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/settings_provider.dart';

class AdvancedSettingsScreen extends ConsumerWidget {
  const AdvancedSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final autoSave = ref.watch(autoSaveProvider);
    final autoClean = ref.watch(autoCleanProvider);
    final themeModeIndex = ref.watch(themeModeProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('高级设置')),
      body: ListView(
        children: [
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 16, 4),
            child: Text('外观',
                style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500)),
          ),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Column(
              children: [
                RadioListTile<int>(
                  title: const Text('跟随系统'),
                  secondary: const Icon(Icons.brightness_auto),
                  value: 0,
                  groupValue: themeModeIndex,
                  onChanged: (v) =>
                      ref.read(themeModeProvider.notifier).set(v!),
                ),
                const Divider(height: 1),
                RadioListTile<int>(
                  title: const Text('浅色模式'),
                  secondary: const Icon(Icons.light_mode),
                  value: 1,
                  groupValue: themeModeIndex,
                  onChanged: (v) =>
                      ref.read(themeModeProvider.notifier).set(v!),
                ),
                const Divider(height: 1),
                RadioListTile<int>(
                  title: const Text('深色模式'),
                  secondary: const Icon(Icons.dark_mode),
                  value: 2,
                  groupValue: themeModeIndex,
                  onChanged: (v) =>
                      ref.read(themeModeProvider.notifier).set(v!),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 16, 4),
            child: Text('功能',
                style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500)),
          ),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('查询后自动保存'),
                  subtitle: const Text('查询快递后自动添加到首页列表'),
                  value: autoSave,
                  onChanged: (value) {
                    ref.read(autoSaveProvider.notifier).set(value);
                  },
                  secondary: Icon(
                    autoSave ? Icons.save : Icons.save_outlined,
                    color: autoSave ? Colors.green : Colors.grey,
                  ),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text('30天自动清理'),
                  subtitle: const Text('自动清除添加超过30天的快递记录'),
                  value: autoClean,
                  onChanged: (value) {
                    ref.read(autoCleanProvider.notifier).set(value);
                  },
                  secondary: Icon(
                    autoClean
                        ? Icons.auto_delete
                        : Icons.auto_delete_outlined,
                    color: autoClean ? Colors.green : Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
