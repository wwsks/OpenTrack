import 'package:flutter_test/flutter_test.dart';
import 'package:opentrack/models/sms_data.dart';
import 'package:opentrack/models/sms_model.dart';
import 'package:opentrack/utils/llm_prompts.dart';

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
}
