import 'package:flutter_test/flutter_test.dart';
import 'package:opentrack/models/sms_model.dart';
import 'package:opentrack/utils/address_normalizer.dart';
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
}
