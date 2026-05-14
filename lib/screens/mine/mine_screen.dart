import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/settings_provider.dart';
import 'settings_screen.dart';
import 'advanced_settings_screen.dart';

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
          _SectionTitle(title: '关于'),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('自邮查'),
            subtitle: Text('v1.0.0'),
          ),
          ListTile(
            leading: const Icon(Icons.code),
            title: const Text('GitHub 项目地址'),
            subtitle: const Text('github.com/wwsks/OpenTrack'),
            trailing: const Icon(Icons.open_in_new),
            onTap: () async {
              final url = Uri.parse('https://github.com/wwsks/OpenTrack');
              if (await canLaunchUrl(url)) {
                await launchUrl(url, mode: LaunchMode.externalApplication);
              }
            },
          ),
        ],
      ),
    );
  }

  void _showApiGuideDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('如何获取快递100 API'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('1. 百度搜索"快递100 API"，进入百递云 API 开放平台'),
              SizedBox(height: 12),
              Text('2. 注册账号，企业名称随便填'),
              SizedBox(height: 12),
              Text('3. 登录进入企业管理后台'),
              SizedBox(height: 12),
              Text('4. 首页点击"实时查询与订阅推送"'),
              SizedBox(height: 12),
              Text('5. 获取授权参数：授权 Key 和 Customer，填入本应用即可使用'),
              SizedBox(height: 16),
              Text('PS：新注册用户可获得免费 100 次查询次数',
                  style: TextStyle(color: Colors.orange, fontSize: 12)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('知道了'),
          ),
        ],
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
