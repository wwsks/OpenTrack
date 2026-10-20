import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../benchmark/eval_runner.dart';

void main() {
  group('评测基准冒烟', () {
    test('数据集可读且离线指标自洽', () {
      final samples = loadDataset(File('benchmark/sms_dataset.jsonl'));
      expect(samples.length, greaterThanOrEqualTo(100));

      final negatives = samples.where((s) => s.isNegative).length;
      expect(negatives, greaterThanOrEqualTo(10));

      final m = runRegexEval(samples);
      expect(m.valid + m.negatives, samples.length);
      expect(m.exactCorrect, lessThanOrEqualTo(m.parseSuccess));
      expect(m.groupingF1, inInclusiveRange(0.0, 1.0));
      expect(m.trueGroups, greaterThan(1));
      // 分类齐全
      expect(samples.map((s) => s.category).toSet(),
          containsAll(['standard', 'nonstandard-code', 'hard', 'negative']));
    });

    test('评测报告包含分类分解与关键指标', () {
      final samples = loadDataset(File('benchmark/sms_dataset.jsonl'));
      final report = buildReport(runRegexEval(samples), samples);
      expect(report, contains('分类分解'));
      expect(report, contains('nonstandard-code'));
      expect(report, contains('精确识别率'));
      expect(report, contains('pairwise'));
    });

    test('地址可接受集合（address_any）生效', () {
      final s = EvalSample.fromJson({
        'id': 'x',
        'body': 'b',
        'station': '站',
        'category': 'standard',
        'label': {
          'code': '1234',
          'address': '甲驿站(一层)',
          'address_any': ['甲驿站'],
        },
      });
      expect(s.addressAccepted('甲驿站'), isTrue);
      expect(s.addressAccepted('甲驿站(一层)'), isTrue);
      expect(s.addressAccepted('乙驿站'), isFalse);
    });
  });
}
