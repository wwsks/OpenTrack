import 'dart:convert';

import 'package:dio/dio.dart';

/// LLM 调用错误类型
enum LlmErrorType {
  /// 网络连接失败 / 超时（无响应）
  network,

  /// 认证失败（HTTP 401/403）
  auth,

  /// 请求过于频繁（HTTP 429）
  rateLimit,

  /// 接口返回异常（其他 HTTP 错误或响应结构不符合预期）
  badResponse,
}

/// LLM 调用异常，携带错误分类与描述
class LlmException implements Exception {
  final LlmErrorType type;
  final String message;

  const LlmException(this.type, this.message);

  @override
  String toString() => 'LlmException(${type.name}): $message';
}

/// OpenAI 兼容接口的 LLM 调用服务
class LlmService {
  LlmService({
    required String baseUrl,
    required String model,
    required String apiKey,
    Dio? dio,
  })  : _baseUrl = baseUrl,
        _model = model,
        _apiKey = apiKey,
        _dio = dio ?? Dio() {
    // 统一 LLM 请求超时 30 秒
    _dio.options
      ..connectTimeout = const Duration(seconds: 30)
      ..sendTimeout = const Duration(seconds: 30)
      ..receiveTimeout = const Duration(seconds: 30);
  }

  final String _baseUrl;
  final String _model;
  final String _apiKey;
  final Dio _dio;

  /// 发送一轮对话，返回模型输出文本
  ///
  /// [jsonMode] 为 true 时请求 JSON 输出（response_format: json_object）。
  /// 失败抛出 [LlmException]，按错误类型分类。
  Future<String> chat({
    required String system,
    required String user,
    bool jsonMode = false,
  }) async {
    // baseUrl 可能带尾部斜杠，去重后再拼接路径
    final url = '${_baseUrl.replaceAll(RegExp(r'/+$'), '')}/chat/completions';
    final data = <String, dynamic>{
      'model': _model,
      'messages': [
        {'role': 'system', 'content': system},
        {'role': 'user', 'content': user},
      ],
      if (jsonMode) 'response_format': {'type': 'json_object'},
    };

    final Response response;
    try {
      response = await _dio.post(
        url,
        options: Options(
          headers: {'Authorization': 'Bearer $_apiKey'},
        ),
        data: data,
      );
    } on DioException catch (e) {
      throw _classify(e);
    }

    // 校验响应结构，不符合预期视为 badResponse
    final body = response.data;
    if (body is! Map) {
      throw const LlmException(LlmErrorType.badResponse, '响应不是 JSON 对象');
    }
    final choices = body['choices'];
    if (choices is! List || choices.isEmpty) {
      throw const LlmException(LlmErrorType.badResponse, '响应缺少 choices');
    }
    final first = choices.first;
    if (first is! Map) {
      throw const LlmException(LlmErrorType.badResponse, 'choices 结构不符合预期');
    }
    final message = first['message'];
    if (message is! Map || message['content'] is! String) {
      throw const LlmException(LlmErrorType.badResponse, '响应缺少 message.content');
    }
    return message['content'] as String;
  }

  /// 从文本中提取 JSON 对象
  ///
  /// 优先提取 ```json 围栏块，否则取首个 `{` 到末个 `}` 的子串；
  /// 解析失败返回 null。
  static Map<String, dynamic>? tryParseJsonObject(String text) {
    var candidate = text.trim();

    // 优先匹配 ```json 围栏块
    final fence = RegExp(r'```json\s*([\s\S]*?)\s*```', caseSensitive: false)
        .firstMatch(candidate);
    if (fence != null) {
      candidate = fence.group(1)!.trim();
    }

    // 取首个 { 到末个 } 的子串
    final start = candidate.indexOf('{');
    final end = candidate.lastIndexOf('}');
    if (start < 0 || end < start) return null;
    candidate = candidate.substring(start, end + 1);

    try {
      final decoded = json.decode(candidate);
      if (decoded is Map<String, dynamic>) return decoded;
      return null;
    } catch (_) {
      return null;
    }
  }

  /// 将 DioException 按响应状态码分类为 LlmException
  LlmException _classify(DioException e) {
    final status = e.response?.statusCode;
    if (status == 401 || status == 403) {
      return LlmException(LlmErrorType.auth, '认证失败（HTTP $status）');
    }
    if (status == 429) {
      return LlmException(LlmErrorType.rateLimit, '请求过于频繁（HTTP 429）');
    }
    if (status != null) {
      return LlmException(LlmErrorType.badResponse, '接口返回异常（HTTP $status）');
    }
    // 无响应（连接失败 / 超时）视为网络错误
    return LlmException(LlmErrorType.network, '网络请求失败: ${e.message}');
  }
}
