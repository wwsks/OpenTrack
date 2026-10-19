import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/theme.dart';
import '../../providers/settings_provider.dart';
import '../../services/update_service.dart';
import 'settings_screen.dart';
import 'advanced_settings_screen.dart';
import 'llm_settings_screen.dart';
import 'recycle_bin_screen.dart';
import '../../animations/animations.dart';

class MineScreen extends ConsumerWidget {
  const MineScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasApi = ref.watch(hasApiConfigProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('我的')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          // Header card
          StaggeredListAnimation(
            index: 0,
            delay: const Duration(milliseconds: 60),
            child: _buildHeader(context, hasApi, theme),
          ),
          const SizedBox(height: 12),

          // Settings section
          StaggeredListAnimation(
            index: 1,
            delay: const Duration(milliseconds: 60),
            child: _SectionTitle(title: '设置'),
          ),
          StaggeredListAnimation(
            index: 2,
            delay: const Duration(milliseconds: 60),
            child: _buildSettingsCard(context, hasApi),
          ),

          const SizedBox(height: 12),

          // Other section
          StaggeredListAnimation(
            index: 5,
            delay: const Duration(milliseconds: 60),
            child: _SectionTitle(title: '其他'),
          ),
          StaggeredListAnimation(
            index: 6,
            delay: const Duration(milliseconds: 60),
            child: _buildOtherCard(context, ref),
          ),

          const SizedBox(height: 12),

          // About section
          StaggeredListAnimation(
            index: 8,
            delay: const Duration(milliseconds: 60),
            child: _SectionTitle(title: '关于'),
          ),
          StaggeredListAnimation(
            index: 9,
            delay: const Duration(milliseconds: 60),
            child: _buildAboutCard(context),
          ),

          const SizedBox(height: 20),
          // 版本号：页面底部居中次要色（版本号维护点之一，见 AGENTS.md）
          Center(
            child: Text(
              '自邮取 v0.4.0',
              style: TextStyle(
                fontSize: AppTheme.fontCaption,
                color: AppTheme.textSecondary(context),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool hasApi, ThemeData theme) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    theme.colorScheme.primary,
                    theme.colorScheme.primary.withValues(alpha: 0.7),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              ),
              child: const Icon(
                Icons.local_shipping,
                color: Colors.white,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '自邮取',
                    style: TextStyle(
                      color: AppTheme.textPrimary(context),
                      fontSize: AppTheme.fontPageTitle,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: hasApi
                              ? AppTheme.accentGreen
                              : AppTheme.accentOrange,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        hasApi ? 'API 已配置' : 'API 未配置',
                        style: TextStyle(
                          fontSize: AppTheme.fontSecondary,
                          color: hasApi
                              ? AppTheme.accentGreen
                              : AppTheme.accentOrange,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: AppTheme.textSecondary(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsCard(BuildContext context, bool hasApi) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        children: [
          ListTile(
            leading: AppTheme.iconPlate(
              Icons.vpn_key,
              color: hasApi ? AppTheme.accentGreen : AppTheme.accentOrange,
            ),
            title: const Text('API 配置'),
            subtitle: Text(hasApi ? '已配置' : '未配置'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                SlideFadeRoute(page: const SettingsScreen()),
              );
            },
          ),
          const Divider(height: 1, indent: 56),
          ListTile(
            leading:
                AppTheme.iconPlate(Icons.help_outline, color: AppTheme.primaryBlue),
            title: const Text('如何获取快递100 API'),
            subtitle: const Text('查看操作指南'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              _showApiGuideDialog(context);
            },
          ),
          const Divider(height: 1, indent: 56),
          ListTile(
            leading:
                AppTheme.iconPlate(Icons.settings, color: AppTheme.primaryBlue),
            title: const Text('高级设置'),
            subtitle: const Text('自动保存、自动清理'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                SlideFadeRoute(page: const AdvancedSettingsScreen()),
              );
            },
          ),
          const Divider(height: 1, indent: 56),
          ListTile(
            leading: AppTheme.iconPlate(Icons.smart_toy_outlined,
                color: AppTheme.accentPurple),
            title: const Text('大模型'),
            subtitle: const Text('模型连接配置与测试'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                SlideFadeRoute(page: const LlmSettingsScreen()),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildOtherCard(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        children: [
          ListTile(
            leading: AppTheme.iconPlate(Icons.delete_outline,
                color: AppTheme.accentRed),
            title: const Text('回收站'),
            subtitle: const Text('查看已删除的快递'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                SlideFadeRoute(page: const RecycleBinScreen()),
              );
            },
          ),
          const Divider(height: 1, indent: 56),
          _AutoCheckUpdateTile(),
        ],
      ),
    );
  }

  Widget _buildAboutCard(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        children: [
          ListTile(
            leading: AppTheme.iconPlate(Icons.info_outline,
                color: AppTheme.primaryBlue),
            title: const Text('自邮取'),
            trailing: IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: '检查更新',
              onPressed: () async {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('正在检查更新...')),
                );
                final updateInfo = await UpdateService.checkForUpdate();
                if (context.mounted) {
                  if (updateInfo != null) {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: Text('发现新版本 v${updateInfo.latestVersion}'),
                        content: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('更新内容：',
                                  style: TextStyle(fontWeight: FontWeight.bold)),
                              const SizedBox(height: 8),
                              Text(updateInfo.releaseNotes.isNotEmpty
                                  ? updateInfo.releaseNotes
                                  : '暂无更新说明'),
                            ],
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('稍后再说'),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.pop(ctx);
                              UpdateService.openDownloadPage(updateInfo.downloadUrl);
                            },
                            child: const Text('去下载'),
                          ),
                        ],
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('已是最新版本')),
                    );
                  }
                }
              },
            ),
          ),
          const Divider(height: 1, indent: 56),
          ListTile(
            leading: AppTheme.iconPlate(Icons.code, color: AppTheme.primaryBlue),
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
                    color: AppTheme.primaryBlue,
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
                  style: TextStyle(color: AppTheme.accentOrange, fontSize: 12)),
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
      secondary: AppTheme.iconPlate(
        autoCheck ? Icons.system_update : Icons.system_update_outlined,
        color: autoCheck ? AppTheme.primaryBlue : AppTheme.textSecondary(context),
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
    // 分区标题走全局规范：4px 主色小竖条 + 13 w600 次要色（AppTheme.sectionTitle）
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 4, 16, 6),
      child: AppTheme.sectionTitle(title),
    );
  }
}
