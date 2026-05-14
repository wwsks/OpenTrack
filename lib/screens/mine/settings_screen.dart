import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/settings_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _keyController = TextEditingController();
  final _customerController = TextEditingController();
  bool _obscureKey = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _keyController.text = ref.read(apiKeyProvider) ?? '';
      _customerController.text = ref.read(customerProvider) ?? '';
    });
  }

  @override
  void dispose() {
    _keyController.dispose();
    _customerController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final key = _keyController.text.trim();
    final customer = _customerController.text.trim();

    if (key.isEmpty || customer.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请填写完整信息')),
      );
      return;
    }

    await ref.read(apiKeyProvider.notifier).set(key);
    await ref.read(customerProvider.notifier).set(customer);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('保存成功')),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final autoSave = ref.watch(autoSaveProvider);
    final autoClean = ref.watch(autoCleanProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // API 配置部分
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('快递100 API 配置',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                    SizedBox(height: 8),
                    Text(
                      '请在快递100企业版后台获取授权 key 和 customer，'
                      '填入下方输入框即可使用查询功能。',
                      style: TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _keyController,
              decoration: InputDecoration(
                labelText: '授权 Key',
                hintText: '请输入快递100授权 key',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.vpn_key),
                suffixIcon: IconButton(
                  icon: Icon(
                      _obscureKey ? Icons.visibility_off : Icons.visibility),
                  onPressed: () =>
                      setState(() => _obscureKey = !_obscureKey),
                ),
              ),
              obscureText: _obscureKey,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _customerController,
              decoration: const InputDecoration(
                labelText: 'Customer',
                hintText: '请输入 customer',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.business),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _save,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('保存'),
            ),

            // 高级设置部分
            const SizedBox(height: 24),
            _SectionTitle(title: '高级设置'),
            const SizedBox(height: 8),
            Card(
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
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          color: Colors.grey.shade600,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
