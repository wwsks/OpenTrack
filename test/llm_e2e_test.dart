/// LLM 真实 API 端到端测试（硅基流动）。
///
/// 安全红线：API Key 只从环境变量 SILICONFLOW_API_KEY 读取，
/// 绝不写入源码/测试/提交，日志与报告中也不打印完整 Key。
/// 未注入环境变量时整组自动 skip，不发起任何网络请求。
///
/// 注意：本文件不能使用 TestWidgetsFlutterBinding（其会拦截 HttpClient
/// 让所有请求返回 400），归一化缓存用内存版存储实现替代 SharedPreferences。
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:opentrack/models/sms_data.dart';
import 'package:opentrack/models/sms_model.dart';
import 'package:opentrack/services/llm_service.dart';
import 'package:opentrack/services/storage_service.dart';
import 'package:opentrack/utils/address_normalizer.dart';
import 'package:opentrack/utils/llm_prompts.dart';

/// 内存版存储：只实现归一化缓存读写，不触碰 SharedPreferences/Hive
class _MemoryStorage extends StorageService {
  Map<String, String> addressMap = {};

  @override
  Future<Map<String, String>> getLlmAddressMap() async => Map.of(addressMap);

  @override
  Future<void> setLlmAddressMap(Map<String, String> map) async {
    addressMap = Map.of(map);
  }
}

/// 构造测试用 SmsData，短信全文不参与 prompt 构造
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
  // Key 仅来自环境变量；为空则整组 skip
  final apiKey = Platform.environment['SILICONFLOW_API_KEY'] ?? '';
  final skipReason =
      apiKey.isEmpty ? '未注入 SILICONFLOW_API_KEY 环境变量，跳过真实 API E2E' : null;

  group('LLM 真实 API E2E（硅基流动）', () {
    late LlmService llm;

    setUp(() {
      // 每个用例独立的空缓存存储，保证每次都是真实 LLM 调用
      llm = LlmService(
        baseUrl: 'https://api.siliconflow.cn/v1',
        model: 'deepseek-ai/DeepSeek-V3',
        apiKey: apiKey,
      );
    });

    test('地址归一化：同站两表述归一到同名，不同站不误合并', () async {
      final normalizer = LlmAddressNormalizer(
        llm: llm,
        storage: _MemoryStorage(),
      );

      // 真实 API 偶发波动（网络抖动/限流会触发降级为原样返回），
      // 标准 E2E 做法：失败重试一次再断言，契约本身不放松
      Map<String, String> result = {};
      for (var attempt = 0; attempt < 2; attempt++) {
        result = await normalizer.normalizeAll([
          '临江南区菜鸟驿站',
          '临江大学南区菜鸟驿站',
          '重庆市渝北区龙兴菜鸟驿站',
        ]);
        final merged = result['临江南区菜鸟驿站'] ==
                result['临江大学南区菜鸟驿站'] &&
            result['重庆市渝北区龙兴菜鸟驿站'] != result['临江南区菜鸟驿站'];
        if (merged) break;
      }

      // 前两者是同一站点的不同表述，必须归一到同一名
      expect(
        result['临江南区菜鸟驿站'],
        result['临江大学南区菜鸟驿站'],
        reason: '同站两表述应归一同名（重试后仍失败可能是 LLM 持续降级）：$result',
      );
      // 第三者是不同站点，绝不能与前者同名（防误合并）
      expect(
        result['重庆市渝北区龙兴菜鸟驿站'],
        isNot(result['临江南区菜鸟驿站']),
        reason: '不同站点不得误合并：$result',
      );
      expect(result['临江南区菜鸟驿站']!.trim(), isNotEmpty);
    }, timeout: const Timeout(Duration(minutes: 2)));

    test('取件清单：两个驿站各 2 个取件码，返回非空清单且含两个驿站名', () async {
      final items = [
        _sms('临江南区菜鸟驿站', '3201', lockerNumber: 'A-1'),
        _sms('临江南区菜鸟驿站', '3202', lockerNumber: 'A-2'),
        _sms('重庆市渝北区龙兴菜鸟驿站', '66'),
        _sms('重庆市渝北区龙兴菜鸟驿站', '88'),
      ];

      final text = await llm.chat(
        system: kPickupListSystemPrompt,
        user: buildPickupListPrompt(items),
      );

      expect(text.trim(), isNotEmpty);
      expect(text, contains('临江南区菜鸟驿站'), reason: '清单应包含驿站名：$text');
      expect(text, contains('重庆市渝北区龙兴菜鸟驿站'), reason: '清单应包含驿站名：$text');
    }, timeout: const Timeout(Duration(minutes: 2)));

    test('ETA：运输中轨迹解析出非空 estimate', () async {
      final text = await llm.chat(
        system: kEtaSystemPrompt,
        user: buildEtaPrompt(
          companyName: '顺丰速运',
          traceContext: '快件已到达【临江转运中心】，已发出，正发往【重庆渝北龙兴营业点】',
          traceTime: '2026-10-18 08:30:00',
        ),
      );

      final eta = tryParseEta(text);
      expect(eta, isNotNull, reason: '应解析出含 estimate/reason 的 JSON：$text');
      expect(eta!.estimate.trim(), isNotEmpty);
    }, timeout: const Timeout(Duration(minutes: 2)));
  }, skip: skipReason);
}
