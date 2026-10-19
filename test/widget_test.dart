import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opentrack/config/theme.dart';
import 'package:opentrack/main.dart';
import 'package:opentrack/models/package.dart';
import 'package:opentrack/providers/settings_provider.dart';
import 'package:opentrack/screens/mine/llm_settings_screen.dart';
import 'package:opentrack/services/storage_service.dart';
import 'package:opentrack/widgets/package_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 假存储：测试环境不初始化 Hive，启动路径触碰到的存储方法全部 override，
/// 其余简单配置走 SharedPreferences mock 初始值
class _FakeStorage extends StorageService {
  /// PackageListNotifier 构造时同步读取，Hive 未初始化会抛 LateError
  @override
  List<Package> getAllPackages() => [];

  /// 回收站入口（Hive），启动路径按需兜底为空
  @override
  List<Package> getDeletedPackages() => [];

  /// 关闭自动清理，跳过 _cleanOldPackages 的删除逻辑
  @override
  Future<bool> getAutoClean() async => false;

  /// 关闭自动检查更新，避免启动时发起真实网络请求
  @override
  Future<bool> getAutoCheckUpdate() async => false;
}

void main() {
  testWidgets('App renders', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          storageServiceProvider.overrideWithValue(_FakeStorage()),
        ],
        child: const OpenTrackApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(MainScreen), findsOneWidget);
  });

  group('LLM 设置页', () {
    /// 挂载设置页：只依赖 SharedPreferences，不触碰 Hive
    Future<void> pumpLlmSettings(WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            storageServiceProvider.overrideWithValue(StorageService()),
          ],
          child: const MaterialApp(home: LlmSettingsScreen()),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('页脚展示隐私负向声明', (WidgetTester tester) async {
      await pumpLlmSettings(tester);

      expect(
        find.textContaining('不发送手机号、快递单号、快递100 API Key 及用户任何身份信息'),
        findsOneWidget,
      );
    });

    testWidgets('底部展示「启用后可用功能」三行简介（逐字）', (WidgetTester tester) async {
      await pumpLlmSettings(tester);

      expect(find.text('启用后可用功能'), findsOneWidget);
      expect(find.text('取件码智能分组 · 同一驿站自动合并'), findsOneWidget);
      expect(find.text('取件清单 · 一键生成到站取件清单'), findsOneWidget);
      expect(find.text('送达估算 · 详情页显示预计送达时间'), findsOneWidget);
    });

    testWidgets('测试连接失败时错误提示标红', (WidgetTester tester) async {
      await pumpLlmSettings(tester);

      await tester.enterText(
          find.byType(TextField).at(0), 'https://api.example.com/v1');
      await tester.enterText(find.byType(TextField).at(1), 'test-model');
      await tester.enterText(find.byType(TextField).at(2), 'bad-key');
      await tester.tap(find.text('测试连接'));
      // 等待请求失败（测试环境 HTTP 被 mock 拦截返回错误）并弹出 SnackBar
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
      expect(snackBar.backgroundColor, AppTheme.accentRed);
      final text = tester.widget<Text>(
        find.descendant(
          of: find.byType(SnackBar),
          matching: find.byType(Text),
        ),
      );
      expect(text.style?.color, Colors.white);

      // 让 SnackBar 自动消失，清理遗留计时器
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    });
  });

  group('视觉约定（Phase 2）', () {
    testWidgets('快递卡片状态 pill 与单号 w600', (WidgetTester tester) async {
      final pkg = Package(
        id: '1',
        trackingNumber: 'SF1234567890',
        companyCode: 'shunfeng',
        companyName: '测试快递',
        // 用静态状态（揽收），避开在途/派件的无限脉冲动画
        status: '1',
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: PackageCard(package: pkg)),
        ),
      );
      await tester.pumpAndSettle();

      // 状态 pill：状态文案 + 状态色 + 12 w600
      final pill = tester.widget<Text>(find.text('揽收'));
      expect(pill.style?.color, AppTheme.statusCollected);
      expect(pill.style?.fontSize, 12);
      expect(pill.style?.fontWeight, FontWeight.w600);

      // 单号用 w600 突出
      final number = tester.widget<Text>(find.text('SF1234567890'));
      expect(number.style?.fontWeight, FontWeight.w600);
    });

    testWidgets('空状态：品牌色图标 + 13px 次要色文案', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => AppTheme.emptyState(
                context,
                icon: Icons.inbox_outlined,
                message: '暂无快递',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final message = tester.widget<Text>(find.text('暂无快递'));
      expect(message.style?.fontSize, 13);
      expect(message.style?.color, AppTheme.lightTextSecondary);

      final icon = tester.widget<Icon>(find.byIcon(Icons.inbox_outlined));
      expect(icon.color, AppTheme.primaryBlue);
    });
  });
}
