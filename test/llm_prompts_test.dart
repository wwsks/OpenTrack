import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opentrack/config/constants.dart';
import 'package:opentrack/models/sms_data.dart';
import 'package:opentrack/models/sms_model.dart';
import 'package:opentrack/providers/llm_provider.dart';
import 'package:opentrack/providers/settings_provider.dart';
import 'package:opentrack/screens/pickup/pickup_screen.dart';
import 'package:opentrack/services/llm_service.dart';
import 'package:opentrack/services/storage_service.dart';
import 'package:opentrack/utils/llm_prompts.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 假 LLM 服务：固定返回清单文本，widget 测试不发起真实网络请求
class _FakeLlmService extends LlmService {
  _FakeLlmService()
      : super(baseUrl: 'https://fake.invalid/v1', model: 'fake', apiKey: 'fake-key');

  @override
  Future<String> chat({
    required String system,
    required String user,
    bool jsonMode = false,
  }) async {
    return '长春理工南区菜鸟驿站\n3201\n\n总计：1 个驿站 1 件';
  }
}

/// 构造测试用 SmsData，短信内容不参与 prompt 构造
SmsData _sms(String address, String code, {String lockerNumber = ''}) {
  return SmsData(
    address: address,
    code: code,
    sms: SmsModel(id: 'sms-$code', body: '短信全文', timestamp: 0),
    id: 'sms-$code',
    lockerNumber: lockerNumber,
  );
}

void main() {
  group('buildPickupListPrompt', () {
    test('包含每项的地址与取件码，柜号为空的行不含「柜号」字样', () {
      final prompt = buildPickupListPrompt([
        _sms('长春理工南区菜鸟驿站', '3201', lockerNumber: '5-2-103'),
        _sms('重庆市渝北区龙兴菜鸟驿站', '88, 91'),
      ]);

      // 有柜号：输出「驿站：xx｜取件码：xx｜柜号：xx」
      expect(
        prompt,
        contains('驿站：长春理工南区菜鸟驿站｜取件码：3201｜柜号：5-2-103'),
      );

      // 无柜号：省略柜号段，整行不含「柜号」字样；多取件码原样透传
      final lines = prompt.split('\n');
      expect(lines.length, 2);
      expect(lines[1], '驿站：重庆市渝北区龙兴菜鸟驿站｜取件码：88, 91');
      expect(lines[1].contains('柜号'), isFalse);
    });
  });

  group('kPickupListSystemPrompt', () {
    test('含「按驿站分组」「柜号升序」「总计」关键词（防 prompt 回归）', () {
      expect(kPickupListSystemPrompt, contains('按驿站分组'));
      expect(kPickupListSystemPrompt, contains('柜号升序'));
      expect(kPickupListSystemPrompt, contains('总计'));
    });
  });

  group('取件清单弹层（覆盖测试）', () {
    /// 构造已配置 LLM 的取件码页面并打开取件清单弹层
    Future<void> openSheet(WidgetTester tester) async {
      // 预置 LLM 配置（启用 + API Key），让 AppBar 显示「生成取件清单」入口
      SharedPreferences.setMockInitialValues({
        AppConstants.keyLlmEnabled: true,
        AppConstants.keyLlmApiKey: 'fake-key',
      });
      // Clipboard.setData 走 SystemChannels.platform，测试环境需 mock，否则抛 MissingPluginException
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async => null,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            storageServiceProvider.overrideWithValue(StorageService()),
            llmServiceProvider.overrideWithValue(_FakeLlmService()),
          ],
          child: const MaterialApp(home: PickupScreen()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.checklist));
      await tester.pumpAndSettle();

      expect(find.byType(BottomSheet), findsOneWidget);
      expect(find.text('取件清单'), findsOneWidget);
    }

    testWidgets('弹层按内容自适应高度，不被 Scaffold 撑成全屏（缺陷回归钉）',
        (tester) async {
      await openSheet(tester);

      // 缺陷根因：Scaffold 布局恒取父约束最大尺寸，弹层内不得再嵌 Scaffold
      expect(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.byType(Scaffold),
        ),
        findsNothing,
      );

      // 验收 A：弹层高度按内容自适应，严格小于屏幕高度（不再全屏覆盖）
      final screenHeight =
          MediaQuery.of(tester.element(find.byType(BottomSheet))).size.height;
      final sheetHeight = tester.getSize(find.byType(BottomSheet)).height;
      expect(sheetHeight, greaterThan(0));
      expect(sheetHeight, lessThan(screenHeight));
    });

    testWidgets('复制后「已复制」反馈对用户清晰可见', (tester) async {
      await openSheet(tester);

      await tester.tap(find.text('复制'));
      await tester.pumpAndSettle();

      // 验收 B：复制后弹层收起，根部 SnackBar「已复制」可见（不再被弹层遮挡）
      expect(find.byType(BottomSheet), findsNothing);
      expect(find.text('已复制'), findsOneWidget);
    });
  });
}
