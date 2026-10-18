import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/theme.dart';
import '../../providers/llm_provider.dart';
import '../../services/llm_service.dart';

class LlmSettingsScreen extends ConsumerStatefulWidget {
  const LlmSettingsScreen({super.key});

  @override
  ConsumerState<LlmSettingsScreen> createState() => _LlmSettingsScreenState();
}

class _LlmSettingsScreenState extends ConsumerState<LlmSettingsScreen> {
  final _baseUrlController = TextEditingController();
  final _modelController = TextEditingController();
  final _apiKeyController = TextEditingController();
  bool _obscureApiKey = true;
  bool _testing = false;

  @override
  void initState() {
    super.initState();
    // 持久化配置在 LlmSettingsNotifier 构造时异步加载，可能晚于本页 build 完成。
    // postFrame 回调与 build 同处一个同步任务，微任务无法在两者之间排空，
    // 因此那里读到的必然是加载前的构造默认态；必须等加载完成后再回填输入框。
    ref.read(llmSettingsProvider.notifier).loaded.then((_) {
      if (!mounted) return;
      final settings = ref.read(llmSettingsProvider);
      _baseUrlController.text = settings.baseUrl;
      _modelController.text = settings.model;
      _apiKeyController.text = settings.apiKey;
    });
  }

  @override
  void dispose() {
    _baseUrlController.dispose();
    _modelController.dispose();
    _apiKeyController.dispose();
    super.dispose();
  }

  /// 测试连接：只向模型服务发送 'ping'，不携带任何用户数据
  Future<void> _testConnection() async {
    final baseUrl = _baseUrlController.text.trim();
    final model = _modelController.text.trim();
    final apiKey = _apiKeyController.text.trim();

    if (baseUrl.isEmpty || model.isEmpty || apiKey.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先填写服务地址、模型名和 API Key')),
      );
      return;
    }

    setState(() => _testing = true);
    try {
      final service = LlmService(
        baseUrl: baseUrl,
        model: model,
        apiKey: apiKey,
      );
      await service.chat(system: 'ping', user: 'ping');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('连接成功')),
        );
      }
    } on LlmException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(llmErrorText(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(llmSettingsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('大模型')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: SwitchListTile(
                title: const Text('启用大模型'),
                subtitle: const Text('开启后可使用大模型相关功能'),
                value: settings.enabled,
                onChanged: (value) {
                  ref.read(llmSettingsProvider.notifier).setEnabled(value);
                },
                secondary: Icon(
                  settings.enabled
                      ? Icons.smart_toy
                      : Icons.smart_toy_outlined,
                  color: settings.enabled
                      ? AppTheme.accentGreen
                      : AppTheme.lightTextSecondary,
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _baseUrlController,
              decoration: const InputDecoration(
                labelText: '服务地址',
                hintText: '请输入 OpenAI 兼容接口地址',
                prefixIcon: Icon(Icons.cloud_outlined),
              ),
              onChanged: (value) {
                ref.read(llmSettingsProvider.notifier).setBaseUrl(value);
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _modelController,
              decoration: const InputDecoration(
                labelText: '模型名',
                hintText: '请输入模型名称',
                prefixIcon: Icon(Icons.abc),
              ),
              onChanged: (value) {
                ref.read(llmSettingsProvider.notifier).setModel(value);
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _apiKeyController,
              decoration: InputDecoration(
                labelText: 'API Key',
                hintText: '请输入 API Key',
                prefixIcon: const Icon(Icons.vpn_key),
                suffixIcon: IconButton(
                  icon: Icon(
                      _obscureApiKey ? Icons.visibility_off : Icons.visibility),
                  onPressed: () =>
                      setState(() => _obscureApiKey = !_obscureApiKey),
                ),
              ),
              obscureText: _obscureApiKey,
              onChanged: (value) {
                ref.read(llmSettingsProvider.notifier).setApiKey(value);
              },
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _testing ? null : _testConnection,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('测试连接'),
            ),
            const SizedBox(height: 16),
            const Text(
              '地址、取件码与物流轨迹等数据将发送至你配置的模型服务，请谨慎选择服务提供方。',
              style: TextStyle(
                color: AppTheme.lightTextSecondary,
                fontSize: 12,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
