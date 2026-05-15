import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/settings_provider.dart';
import 'settings_screen.dart';
import 'advanced_settings_screen.dart';
import 'recycle_bin_screen.dart';

class MineScreen extends ConsumerWidget {
  const MineScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasApi = ref.watch(hasApiConfigProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('我的')),
      body: ListView(
        children: [
          const SizedBox(height: 16),
          _SectionTitle(title: '设置'),
          ListTile(
            leading: Icon(Icons.vpn_key,
                color: hasApi ? Colors.green : Colors.orange),
            title: const Text('API 配置'),
            subtitle: Text(hasApi ? '已配置' : '未配置'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.help_outline),
            title: const Text('如何获取快递100 API'),
            subtitle: const Text('查看操作指南'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              _showApiGuideDialog(context);
            },
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('高级设置'),
            subtitle: const Text('自动保存、自动清理'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const AdvancedSettingsScreen()),
              );
            },
          ),
          _SectionTitle(title: '其他'),
          ListTile(
            leading: const Icon(Icons.delete_outline),
            title: const Text('回收站'),
            subtitle: const Text('查看已删除的快递'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const RecycleBinScreen()),
              );
            },
          ),
          const Divider(height: 1),
          _AutoCheckUpdateTile(),
          _SectionTitle(title: '关于'),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('自邮查'),
            subtitle: Text('v0.1.2 beta'),
          ),
          ListTile(
            leading: const Icon(Icons.code),
            title: const Text('GitHub 项目地址'),
            subtitle: const Text('github.com/wwsks/OpenTrack'),
            trailing: const Icon(Icons.open_in_new),
            onTap: () async {
              final url = Uri.parse('https://github.com/wwsks/OpenTrack');
              await launchUrl(url, mode: LaunchMode.externalApplication);
            },
          ),
        ],
      ),
    );
  }

  void _showApiGuideDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('如何获取快递100 API'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('1. 点击下方链接进入百递云 API 开放平台：'),
              const SizedBox(height: 4),
              InkWell(
                onTap: () async {
                  final url = Uri.parse('https://api.kuaidi100.com');
                  await launchUrl(url, mode: LaunchMode.externalApplication);
                },
                child: const Text(
                  'https://api.kuaidi100.com',
                  style: TextStyle(
                    color: Colors.blue,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text('2. 注册账号，企业名称随便填'),
              const SizedBox(height: 12),
              const Text('3. 登录进入企业管理后台'),
              const SizedBox(height: 12),
              const Text('4. 首页点击"实时查询与订阅推送" → "快递信息订阅推送API" → "立即免费体验"'),
              const SizedBox(height: 12),
              const Text('5. 获取授权参数：授权 Key 和 Customer，填入本应用即可使用'),
              const SizedBox(height: 16),
              const Text('PS：新注册用户可获得免费 100 次查询次数',
                  style: TextStyle(color: Colors.orange, fontSize: 12)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }
}

class _AutoCheckUpdateTile extends ConsumerWidget {
  const _AutoCheckUpdateTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final autoCheck = ref.watch(autoCheckUpdateProvider);
    return SwitchListTile(
      secondary: Icon(
        autoCheck ? Icons.system_update : Icons.system_update_outlined,
        color: autoCheck ? Colors.blue : Colors.grey,
      ),
      title: const Text('自动检查更新'),
      subtitle: const Text('打开应用时检查是否有新版本'),
      value: autoCheck,
      onChanged: (value) {
        ref.read(autoCheckUpdateProvider.notifier).set(value);
      },
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
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
