import 'package:flutter_test/flutter_test.dart';
import 'package:opentrack/models/sms_data.dart';
import 'package:opentrack/models/sms_model.dart';
import 'package:opentrack/utils/address_normalizer.dart';
import 'package:opentrack/utils/sms_fallback_extractor.dart';
import 'package:opentrack/utils/sms_parser.dart';
import 'package:opentrack/utils/sms_processor.dart';

/// 按预置映射返回标准化地址的假归一化器，未命中的原样返回
class _FakeNormalizer implements AddressNormalizer {
  _FakeNormalizer(this.mapping);

  final Map<String, String> mapping;

  @override
  Future<Map<String, String>> normalizeAll(List<String> addresses) async {
    return {for (final a in addresses) a: mapping[a] ?? a};
  }
}

/// 可配置行为的假兜底提取器
class _FakeFallback implements SmsFallbackExtractor {
  _FakeFallback({this.onExtract});

  final Future<List<SmsData>> Function(List<SmsModel> failed)? onExtract;

  @override
  Future<List<SmsData>> extractFailed(List<SmsModel> failed) async {
    if (onExtract != null) return onExtract!(failed);
    return [];
  }
}

void main() {
  final parser = SmsParser();

  const addressA = '临江南区菜鸟驿站';
  const addressB = '临江大学南区菜鸟驿站';
  const standardName = '临江大学南区菜鸟驿站';

  List<SmsModel> twoMessages() => [
        SmsModel(
          id: '1',
          body: '【极兔速递】请凭3-2-5031到临江南区菜鸟驿站取运单尾号2081包裹',
          timestamp: 1760000000000,
        ),
        SmsModel(
          id: '2',
          body: '【圆通快递】请凭4-6-3017到临江大学南区菜鸟驿站取运单尾号6799包裹',
          timestamp: 1760000060000,
        ),
      ];

  test('两个相似地址合并为一组', () async {
    final normalizer = _FakeNormalizer({
      addressA: standardName,
      addressB: standardName,
    });

    final result =
        await SmsProcessor.process(twoMessages(), parser, [], normalizer: normalizer);

    expect(result.parcels.length, 1);
    expect(result.parcels.first.address, standardName);
    expect(result.parcels.first.smsDataList.length, 2);
    expect(result.failed, isEmpty);
    // SmsData.address 保持原始地址不变
    expect(result.successful.map((s) => s.address).toSet(), {addressA, addressB});
  });

  test('normalizer 返回原名时独立分组', () async {
    final normalizer = _FakeNormalizer({
      addressA: addressA,
      addressB: addressB,
    });

    final result =
        await SmsProcessor.process(twoMessages(), parser, [], normalizer: normalizer);

    expect(result.parcels.length, 2);
  });

  test('null normalizer 保持现状分组', () async {
    final result = await SmsProcessor.process(twoMessages(), parser, []);

    expect(result.parcels.length, 2);
    expect(result.parcels.map((p) => p.address).toSet(), {addressA, addressB});
  });

  group('LLM 兜底提取', () {
    SmsModel unparseable() => SmsModel(
          id: '9',
          body: '【菜鸟】您的包裹已到楼下，请尽快来取一下哦',
          timestamp: 1760000120000,
        );

    test('恢复的短信移出 failed 并入成功流分组', () async {
      final fallback = _FakeFallback(onExtract: (failed) async {
        return [
          SmsData(
            address: addressA,
            code: '9-1-2048',
            sms: failed.first,
            id: '${failed.first.id}_${failed.first.timestamp}',
            lockerNumber: '5-2-103',
            extractedByLlm: true,
          ),
        ];
      });

      final result = await SmsProcessor.process(
        [...twoMessages(), unparseable()],
        parser,
        [],
        fallback: fallback,
      );

      expect(result.failed, isEmpty);
      expect(result.successful.length, 3);
      expect(
          result.successful.where((s) => s.extractedByLlm).length, 1);
      // 恢复条目走同一分组管线（addressA 组含原始 + 恢复两条）
      final groupA =
          result.parcels.firstWhere((p) => p.address == addressA);
      expect(groupA.smsDataList.length, 2);
    });

    test('fallback 返回空时 failed 原样保留', () async {
      final result = await SmsProcessor.process(
        [...twoMessages(), unparseable()],
        parser,
        [],
        fallback: _FakeFallback(),
      );

      expect(result.failed.length, 1);
      expect(result.failed.first.id, '9');
      expect(result.successful.length, 2);
    });

    test('fallback 抛异常时 failed 原样保留且不影响主流程', () async {
      final fallback = _FakeFallback(
        onExtract: (failed) async => throw Exception('LLM 挂了'),
      );

      final result = await SmsProcessor.process(
        [...twoMessages(), unparseable()],
        parser,
        [],
        fallback: fallback,
      );

      expect(result.failed.length, 1);
      expect(result.successful.length, 2);
    });

    test('null fallback 保持现状（failed 不走 LLM）', () async {
      final result = await SmsProcessor.process(
        [...twoMessages(), unparseable()],
        parser,
        [],
      );

      expect(result.failed.length, 1);
      expect(result.successful.length, 2);
    });
  });
}
