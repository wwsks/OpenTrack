import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../providers/settings_provider.dart';

class _CustomRulesScreen extends StatefulWidget {
  const _CustomRulesScreen();

  @override
  State<_CustomRulesScreen> createState() => _CustomRulesScreenState();
}

class _CustomRulesScreenState extends State<_CustomRulesScreen> {
  List<String> _codePatterns = [];
  List<String> _ignoreKeywords = [];

  @override
  void initState() {
    super.initState();
    _loadRules();
  }

  Future<void> _loadRules() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _codePatterns = prefs.getStringList('custom_code_patterns') ?? [];
      _ignoreKeywords = prefs.getStringList('ignore_keywords') ?? [];
    });
  }

  Future<void> _removeCodePattern(int index) async {
    final prefs = await SharedPreferences.getInstance();
    _codePatterns.removeAt(index);
    await prefs.setStringList('custom_code_patterns', _codePatterns);
    setState(() {});
  }

  Future<void> _removeIgnoreKeyword(int index) async {
    final prefs = await SharedPreferences.getInstance();
    _ignoreKeywords.removeAt(index);
    await prefs.setStringList('ignore_keywords', _ignoreKeywords);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('自定义解析规则')),
      body: ListView(
        children: [
          if (_codePatterns.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 16, 4),
              child: Text('取件码规则 (${_codePatterns.length})',
                  style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500)),
            ),
            ..._codePatterns.asMap().entries.map((entry) {
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: ListTile(
                  title: Text(
                    entry.value,
                    style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () => _removeCodePattern(entry.key),
                  ),
                ),
              );
            }),
          ],
          if (_ignoreKeywords.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 16, 4),
              child: Text('忽略关键词 (${_ignoreKeywords.length})',
                  style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500)),
            ),
            ..._ignoreKeywords.asMap().entries.map((entry) {
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: ListTile(
                  title: Text(entry.value),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () => _removeIgnoreKeyword(entry.key),
                  ),
                ),
              );
            }),
          ],
          if (_codePatterns.isEmpty && _ignoreKeywords.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(64),
                child: Column(
                  children: [
                    Icon(Icons.rule_outlined, size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text('暂无自定义规则', style: TextStyle(color: Colors.grey, fontSize: 16)),
                    SizedBox(height: 8),
                    Text('在取件码页面解析失败的短信中可添加规则',
                        style: TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class AdvancedSettingsScreen extends ConsumerWidget {
  const AdvancedSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final autoSave = ref.watch(autoSaveProvider);
    final autoClean = ref.watch(autoCleanProvider);
    final themeModeIndex = ref.watch(themeModeProvider);
    final hideCompleted = ref.watch(hideCompletedPickupsProvider);

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
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text('隐藏已取快递'),
                  subtitle: const Text('已标记取出的取件码不再显示'),
                  value: hideCompleted,
                  onChanged: (value) {
                    ref.read(hideCompletedPickupsProvider.notifier).set(value);
                  },
                  secondary: Icon(
                    hideCompleted ? Icons.visibility_off : Icons.visibility,
                    color: hideCompleted ? Colors.green : Colors.grey,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 16, 4),
            child: Text('取件码',
                style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500)),
          ),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.rule, color: Colors.blue),
                  title: const Text('自定义解析规则'),
                  subtitle: const Text('查看和管理自定义的取件码解析规则'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const _CustomRulesScreen()),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
