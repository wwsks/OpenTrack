import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opentrack/config/theme.dart';
import 'package:opentrack/main.dart';
import 'package:opentrack/models/package.dart';
import 'package:opentrack/providers/settings_provider.dart';
import 'package:opentrack/screens/mine/llm_settings_screen.dart';
import 'package:opentrack/services/storage_service.dart';
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
}
