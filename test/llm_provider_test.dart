import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:opentrack/config/constants.dart';
import 'package:opentrack/providers/llm_provider.dart';
import 'package:opentrack/providers/settings_provider.dart';
import 'package:opentrack/screens/mine/llm_settings_screen.dart';
import 'package:opentrack/services/llm_service.dart';
import 'package:opentrack/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  /// 创建带 fake 存储的 ProviderContainer（真实 StorageService + mock SharedPreferences）
  ///
  /// Provider 是惰性创建的，构造函数里的异步加载在首次 read 时才触发，
  /// 因此这里先 read 实例化 llmSettingsProvider，再等加载完成。
  Future<ProviderContainer> createLoadedContainer() async {
    final container = ProviderContainer(
      overrides: [
        storageServiceProvider.overrideWithValue(StorageService()),
      ],
    );
    addTearDown(container.dispose);
    container.read(llmSettingsProvider);
    await pumpEventQueue();
    return container;
  }

  group('llmSettingsProvider', () {
    test('初始状态为默认值且 isConfigured 为 false', () async {
      final container = await createLoadedContainer();

      final settings = container.read(llmSettingsProvider);
      expect(settings.enabled, false);
      expect(settings.baseUrl, 'https://api.deepseek.com/v1');
      expect(settings.model, 'deepseek-chat');
      expect(settings.apiKey, '');
      expect(settings.isConfigured, false);
    });

    test('setApiKey + setEnabled 后 isConfigured 为 true 并持久化', () async {
      final container = await createLoadedContainer();

      await container.read(llmSettingsProvider.notifier).setApiKey('k');
      await container.read(llmSettingsProvider.notifier).setEnabled(true);

      final settings = container.read(llmSettingsProvider);
      expect(settings.apiKey, 'k');
      expect(settings.enabled, true);
      expect(settings.isConfigured, true);

      // 新建 container 从持久化存储读回同样的值
      final container2 = await createLoadedContainer();

      final reloaded = container2.read(llmSettingsProvider);
      expect(reloaded.apiKey, 'k');
      expect(reloaded.enabled, true);
      expect(reloaded.isConfigured, true);
    });
  });

  group('llmServiceProvider', () {
    test('isConfigured 为 false 时为 null', () async {
      final container = await createLoadedContainer();

      expect(container.read(llmServiceProvider), isNull);
    });

    test('配置齐全后为 LlmService 实例', () async {
      final container = await createLoadedContainer();

      await container.read(llmSettingsProvider.notifier).setApiKey('k');
      await container.read(llmSettingsProvider.notifier).setEnabled(true);

      expect(container.read(llmServiceProvider), isA<LlmService>());
    });
  });

  group('llmErrorText', () {
    test('auth 返回「API Key 无效，请检查后重试」', () {
      expect(
        llmErrorText(const LlmException(LlmErrorType.auth, '认证失败')),
        'API Key 无效，请检查后重试',
      );
    });

    test('rateLimit 返回「请求过于频繁，请稍后重试」', () {
      expect(
        llmErrorText(const LlmException(LlmErrorType.rateLimit, '请求过于频繁')),
        '请求过于频繁，请稍后重试',
      );
    });

    test('其余错误返回「连接失败，请稍后重试」', () {
      expect(
        llmErrorText(const LlmException(LlmErrorType.network, '网络错误')),
        '连接失败，请稍后重试',
      );
      expect(
        llmErrorText(const LlmException(LlmErrorType.badResponse, '响应异常')),
        '连接失败，请稍后重试',
      );
    });
  });

  group('LlmSettingsScreen 输入框回填', () {
    /// 读取第 [index] 个 TextField 的 controller 文本
    String fieldText(WidgetTester tester, int index) {
      final field = tester.widget<TextField>(find.byType(TextField).at(index));
      return field.controller!.text;
    }

    testWidgets('首次进入页面时输入框显示已持久化配置而非默认值/空值', (tester) async {
      // 预置持久化配置，模拟冷启动后首次进入「大模型」页
      SharedPreferences.setMockInitialValues({
        AppConstants.keyLlmEnabled: true,
        AppConstants.keyLlmBaseUrl: 'https://api.example.com/v1',
        AppConstants.keyLlmModel: 'my-model',
        AppConstants.keyLlmApiKey: 'secret-key',
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            storageServiceProvider.overrideWithValue(StorageService()),
          ],
          child: const MaterialApp(home: LlmSettingsScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // 三个输入框必须显示持久化值（构造默认态是默认地址/deepseek-chat/空 Key）
      expect(fieldText(tester, 0), 'https://api.example.com/v1');
      expect(fieldText(tester, 1), 'my-model');
      expect(fieldText(tester, 2), 'secret-key');
    });
  });
}
