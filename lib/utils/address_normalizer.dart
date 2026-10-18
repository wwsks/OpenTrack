import '../services/llm_service.dart';
import '../services/storage_service.dart';
import 'llm_prompts.dart';

/// 地址归一化接口
abstract class AddressNormalizer {
  /// 返回原地址到标准名的映射，须覆盖全部输入地址；未命中的原样映射
  Future<Map<String, String>> normalizeAll(List<String> addresses);
}

/// 基于 LLM + 本地缓存的地址归一化
///
/// 缓存全命中时不调用 LLM；查询失败或解析失败时不写缓存、未命中的原样返回。
class LlmAddressNormalizer implements AddressNormalizer {
  LlmAddressNormalizer({
    required LlmService llm,
    required StorageService storage,
    Future<String?> Function(List<String> addresses)? bulkQuery,
  })  : _llm = llm,
        _storage = storage,
        _bulkQuery = bulkQuery;

  final LlmService _llm;
  final StorageService _storage;

  /// 测试钩子：批量查询未命中地址，返回 JSON 文本或 null；默认走 LLM
  final Future<String?> Function(List<String> addresses)? _bulkQuery;

  /// 默认批量查询：调用 LLM 并校验返回可解析的 JSON，解析失败返回 null
  Future<String?> _queryViaLlm(List<String> addresses) async {
    final text = await _llm.chat(
      system: kNormalizeSystemPrompt,
      user: buildNormalizePrompt(addresses),
      jsonMode: true,
    );
    return LlmService.tryParseJsonObject(text) == null ? null : text;
  }

  @override
  Future<Map<String, String>> normalizeAll(List<String> addresses) async {
    final unique = addresses.toSet();
    // 读缓存失败按空缓存降级：LLM 是增强层，绝不阻塞短信处理主流程
    Map<String, String> cache;
    try {
      cache = await _storage.getLlmAddressMap();
    } catch (_) {
      cache = {};
    }

    final result = <String, String>{};
    final missing = <String>[];
    for (final address in unique) {
      final hit = cache[address];
      if (hit != null && hit.isNotEmpty) {
        result[address] = hit;
      } else {
        missing.add(address);
      }
    }

    // 缓存全命中：直接返回，不触发 LLM
    if (missing.isEmpty) return _coverAll(unique, result);

    final query = _bulkQuery ?? _queryViaLlm;
    final String? raw;
    try {
      raw = await query(missing);
    } catch (_) {
      // 调用失败：不写缓存，未命中的原样返回
      return _coverAll(unique, result);
    }
    final parsed = raw == null ? null : LlmService.tryParseJsonObject(raw);
    if (parsed == null) {
      // 解析失败：不写缓存，未命中的原样返回
      return _coverAll(unique, result);
    }

    // 只合并键在输入集合中且值为非空字符串的条目，无关键不进缓存
    final merged = Map<String, String>.from(cache);
    for (final entry in parsed.entries) {
      final value = entry.value;
      if (!unique.contains(entry.key)) continue;
      if (value is! String || value.isEmpty) continue;
      merged[entry.key] = value;
      result[entry.key] = value;
    }
    await _storage.setLlmAddressMap(merged);

    return _coverAll(unique, result);
  }

  /// 补齐未命中地址的原样映射，保证结果覆盖全部输入
  Map<String, String> _coverAll(Set<String> addresses, Map<String, String> result) {
    return {for (final a in addresses) a: result[a] ?? a};
  }
}
