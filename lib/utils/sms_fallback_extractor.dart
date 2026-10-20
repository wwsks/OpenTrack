import '../models/sms_data.dart';
import '../models/sms_model.dart';
import '../services/llm_service.dart';
import 'llm_prompts.dart';

/// 失败短信兜底提取器：正则解析失败的短信交给 LLM 提取取件信息。
abstract class SmsFallbackExtractor {
  /// 从解析失败的短信中提取取件信息，返回恢复的 [SmsData] 列表。
  /// 失败/脏输出一律返回空列表（降级），不抛出。
  Future<List<SmsData>> extractFailed(List<SmsModel> failed);
}

/// LLM 实现：批量送 LLM 提取（每批最多 [maxBatchSize] 条），
/// 调用失败/脏 JSON 的批次整体放弃，不影响其他批次。
class LlmSmsFallbackExtractor implements SmsFallbackExtractor {
  LlmSmsFallbackExtractor({required this.llm, this.bulkQuery});

  final LlmService llm;

  /// 测试钩子：默认走 [LlmService.chat] 批量请求
  final Future<String?> Function(List<SmsModel> batch)? bulkQuery;

  static const int maxBatchSize = 20;

  @override
  Future<List<SmsData>> extractFailed(List<SmsModel> failed) async {
    final recovered = <SmsData>[];
    for (var start = 0; start < failed.length; start += maxBatchSize) {
      final end = (start + maxBatchSize).clamp(0, failed.length);
      final batch = failed.sublist(start, end);

      String? raw;
      try {
        raw = bulkQuery != null
            ? await bulkQuery!(batch)
            : await llm.chat(
                system: kFallbackExtractSystemPrompt,
                user: buildFallbackExtractPrompt(batch),
                jsonMode: true,
              );
      } catch (_) {
        continue; // 该批次放弃，不影响其他批次
      }
      if (raw == null) continue;

      final parsed = LlmService.tryParseJsonObject(raw);
      if (parsed == null) continue;

      for (final entry in parsed.entries) {
        final idx = int.tryParse(entry.key);
        if (idx == null || idx < 1 || idx > batch.length) continue;
        final value = entry.value;
        if (value is! Map) continue;
        final code = value['code'];
        if (code is! String || code.trim().isEmpty) continue;

        final sms = batch[idx - 1];
        final address = value['address'];
        final locker = value['locker'];
        recovered.add(SmsData(
          address: address is String && address.trim().isNotEmpty
              ? address.trim()
              : '未知地址',
          code: code.trim(),
          sms: sms,
          id: '${sms.id}_${sms.timestamp}',
          lockerNumber: locker is String ? locker.trim() : '',
          extractedByLlm: true,
        ));
      }
    }
    return recovered;
  }
}
