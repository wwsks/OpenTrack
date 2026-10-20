import 'package:flutter_test/flutter_test.dart';
import 'package:opentrack/models/sms_model.dart';
import 'package:opentrack/services/llm_service.dart';
import 'package:opentrack/utils/sms_fallback_extractor.dart';

SmsModel _sms(String id, String body) =>
    SmsModel(id: id, body: body, timestamp: 1700000000000);

void main() {
  final llm = LlmService(
      baseUrl: 'https://example.invalid/v1', model: 'm', apiKey: 'k');

  group('LlmSmsFallbackExtractor', () {
    test('按序号从 JSON 提取，构建 SmsData 且 extractedByLlm 为 true', () async {
      List<SmsModel>? queried;
      final extractor = LlmSmsFallbackExtractor(
        llm: llm,
        bulkQuery: (batch) async {
          queried = batch;
          return '{"1":{"code":"9-1-2048","address":"临江南区菜鸟驿站","locker":"5-2-103"}}';
        },
      );
      final failed = [
        _sms('a', '【妈妈驿站】包裹已到，凭9-1-2048取，货架5-2-103'),
      ];
      final result = await extractor.extractFailed(failed);

      expect(result, hasLength(1));
      final data = result.first;
      expect(data.code, '9-1-2048');
      expect(data.address, '临江南区菜鸟驿站');
      expect(data.lockerNumber, '5-2-103');
      expect(data.extractedByLlm, isTrue);
      expect(data.sms.id, 'a');
      expect(data.id, 'a_1700000000000');
      expect(queried, failed);
    });

    test('无 code / 空 code 的条目被跳过（不编造取件码）', () async {
      final extractor = LlmSmsFallbackExtractor(
        llm: llm,
        bulkQuery: (batch) async =>
            '{"1":{"code":"","address":"甲地"},"2":{"address":"乙地"},"3":{"code":"1234","address":"临江南区菜鸟驿站"}}',
      );
      final result = await extractor.extractFailed([
        _sms('a', '1'),
        _sms('b', '2'),
        _sms('c', '3'),
      ]);
      expect(result, hasLength(1));
      expect(result.first.sms.id, 'c');
    });

    test('地址缺失时回退「未知地址」', () async {
      final extractor = LlmSmsFallbackExtractor(
        llm: llm,
        bulkQuery: (batch) async => '{"1":{"code":"1234"}}',
      );
      final result = await extractor.extractFailed([_sms('a', 'x')]);
      expect(result.single.address, '未知地址');
    });

    test('脏 JSON 时返回空列表，不抛出', () async {
      final extractor = LlmSmsFallbackExtractor(
        llm: llm,
        bulkQuery: (batch) async => '抱歉，我无法处理这个请求',
      );
      final result = await extractor.extractFailed([_sms('a', 'x')]);
      expect(result, isEmpty);
    });

    test('bulkQuery 返回 null 时返回空列表', () async {
      final extractor = LlmSmsFallbackExtractor(
        llm: llm,
        bulkQuery: (batch) async => null,
      );
      expect(await extractor.extractFailed([_sms('a', 'x')]), isEmpty);
    });

    test('调用抛异常时返回空列表，不抛出', () async {
      final extractor = LlmSmsFallbackExtractor(
        llm: llm,
        bulkQuery: (batch) async => throw Exception('网络失败'),
      );
      expect(await extractor.extractFailed([_sms('a', 'x')]), isEmpty);
    });

    test('超过 20 条自动分批调用', () async {
      var calls = 0;
      final extractor = LlmSmsFallbackExtractor(
        llm: llm,
        bulkQuery: (batch) async {
          calls++;
          return '{}';
        },
      );
      await extractor.extractFailed(List.generate(25, (i) => _sms('$i', 'b$i')));
      expect(calls, 2);
    });

    test('无关键（超出批次序号）被忽略', () async {
      final extractor = LlmSmsFallbackExtractor(
        llm: llm,
        bulkQuery: (batch) async =>
            '{"1":{"code":"1234","address":"临江南区菜鸟驿站"},"99":{"code":"9999","address":"幽灵"}}',
      );
      final result = await extractor.extractFailed([_sms('a', 'x')]);
      expect(result, hasLength(1));
      expect(result.first.code, '1234');
    });
  });
}
