import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/llm_service.dart';
import '../services/storage_service.dart';
import 'settings_provider.dart';

/// LLM 配置（不可变）
class LlmSettings {
  final bool enabled;
  final String baseUrl;
  final String model;
  final String apiKey;

  const LlmSettings({
    this.enabled = false,
    this.baseUrl = 'https://api.deepseek.com/v1',
    this.model = 'deepseek-chat',
    this.apiKey = '',
  });

  /// 是否已配置可用（启用且填写了 API Key）
  bool get isConfigured => enabled && apiKey.isNotEmpty;

  LlmSettings copyWith({
    bool? enabled,
    String? baseUrl,
    String? model,
    String? apiKey,
  }) {
    return LlmSettings(
      enabled: enabled ?? this.enabled,
      baseUrl: baseUrl ?? this.baseUrl,
      model: model ?? this.model,
      apiKey: apiKey ?? this.apiKey,
    );
  }
}

final llmSettingsProvider =
    StateNotifierProvider<LlmSettingsNotifier, LlmSettings>((ref) {
  return LlmSettingsNotifier(ref.read(storageServiceProvider));
});

/// LLM 调用服务：配置齐全时按当前配置构造，否则为 null
final llmServiceProvider = Provider<LlmService?>((ref) {
  final settings = ref.watch(llmSettingsProvider);
  if (!settings.isConfigured) return null;
  return LlmService(
    baseUrl: settings.baseUrl,
    model: settings.model,
    apiKey: settings.apiKey,
  );
});

class LlmSettingsNotifier extends StateNotifier<LlmSettings> {
  final StorageService _storage;
  LlmSettingsNotifier(this._storage) : super(const LlmSettings()) {
    _load();
  }

  Future<void> _load() async {
    final enabled = await _storage.getLlmEnabled();
    final baseUrl = await _storage.getLlmBaseUrl();
    final model = await _storage.getLlmModel();
    final apiKey = await _storage.getLlmApiKey();
    state = LlmSettings(
      enabled: enabled,
      baseUrl: baseUrl,
      model: model,
      apiKey: apiKey,
    );
  }

  Future<void> setEnabled(bool value) async {
    await _storage.setLlmEnabled(value);
    state = state.copyWith(enabled: value);
  }

  Future<void> setBaseUrl(String value) async {
    await _storage.setLlmBaseUrl(value);
    state = state.copyWith(baseUrl: value);
  }

  Future<void> setModel(String value) async {
    await _storage.setLlmModel(value);
    state = state.copyWith(model: value);
  }

  Future<void> setApiKey(String value) async {
    await _storage.setLlmApiKey(value);
    state = state.copyWith(apiKey: value);
  }
}

/// 将 [LlmException] 转为用户可读的错误提示
String llmErrorText(LlmException e) {
  switch (e.type) {
    case LlmErrorType.auth:
      return 'API Key 无效，请检查后重试';
    case LlmErrorType.rateLimit:
      return '请求过于频繁，请稍后重试';
    default:
      return '连接失败，请稍后重试';
  }
}
