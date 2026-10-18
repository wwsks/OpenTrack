import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opentrack/main.dart';
import 'package:opentrack/models/package.dart';
import 'package:opentrack/providers/settings_provider.dart';
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
}
