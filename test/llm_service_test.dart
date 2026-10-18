import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opentrack/services/llm_service.dart';

/// 测试用 HTTP 适配器：返回预设响应或抛出预设异常，同时记录请求 URL 与请求体
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter({this.body, this.statusCode = 200, this.error});

  final String? body;
  final int statusCode;
  final Object? error;

  String? requestedUrl;
  Map<String, dynamic>? requestedJson;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requestedUrl = options.uri.toString();
    if (requestStream != null) {
      final bytes = <int>[];
      await for (final chunk in requestStream) {
        bytes.addAll(chunk);
      }
      requestedJson = json.decode(utf8.decode(bytes)) as Map<String, dynamic>;
    }
    if (error != null) {
      throw error!;
    }
    return ResponseBody.fromString(
      body ?? '',
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

LlmService _buildService(_FakeAdapter adapter, {String baseUrl = 'https://api.deepseek.com/v1'}) {
  final dio = Dio()..httpClientAdapter = adapter;
  return LlmService(
    baseUrl: baseUrl,
    model: 'deepseek-chat',
    apiKey: 'test-key',
    dio: dio,
  );
}

void main() {
  group('chat', () {
    test('成功时返回 content，请求体含 model/messages，URL 正确', () async {
      final adapter = _FakeAdapter(
        body: '{"choices":[{"message":{"content":"你好"}}]}',
      );
      final service = _buildService(adapter);

      final result = await service.chat(system: '你是助手', user: '打个招呼');

      expect(result, '你好');
      expect(adapter.requestedUrl, 'https://api.deepseek.com/v1/chat/completions');
      expect(adapter.requestedJson?['model'], 'deepseek-chat');
      final messages = adapter.requestedJson?['messages'] as List;
      expect(messages, hasLength(2));
      expect(messages[0]['role'], 'system');
      expect(messages[0]['content'], '你是助手');
      expect(messages[1]['role'], 'user');
      expect(messages[1]['content'], '打个招呼');
    });

    test('baseUrl 带尾部斜杠时 URL 不出现重复斜杠', () async {
      final adapter = _FakeAdapter(
        body: '{"choices":[{"message":{"content":"你好"}}]}',
      );
      final service = _buildService(adapter, baseUrl: 'https://api.deepseek.com/v1/');

      await service.chat(system: 's', user: 'u');

      expect(adapter.requestedUrl, 'https://api.deepseek.com/v1/chat/completions');
    });

    test('jsonMode 时请求体含 response_format', () async {
      final adapter = _FakeAdapter(
        body: '{"choices":[{"message":{"content":"{}"}}]}',
      );
      final service = _buildService(adapter);

      await service.chat(system: 's', user: 'u', jsonMode: true);

      expect(adapter.requestedJson?['response_format'], {'type': 'json_object'});
    });

    test('默认不带 response_format', () async {
      final adapter = _FakeAdapter(
        body: '{"choices":[{"message":{"content":"你好"}}]}',
      );
      final service = _buildService(adapter);

      await service.chat(system: 's', user: 'u');

      expect(adapter.requestedJson?.containsKey('response_format'), false);
    });

    test('401 抛 LlmException(auth)', () async {
      final adapter = _FakeAdapter(body: '{"error":"invalid key"}', statusCode: 401);
      final service = _buildService(adapter);

      await expectLater(
        service.chat(system: 's', user: 'u'),
        throwsA(isA<LlmException>()
            .having((e) => e.type, 'type', LlmErrorType.auth)),
      );
    });

    test('403 抛 LlmException(auth)', () async {
      final adapter = _FakeAdapter(body: '{}', statusCode: 403);
      final service = _buildService(adapter);

      await expectLater(
        service.chat(system: 's', user: 'u'),
        throwsA(isA<LlmException>()
            .having((e) => e.type, 'type', LlmErrorType.auth)),
      );
    });

    test('429 抛 LlmException(rateLimit)', () async {
      final adapter = _FakeAdapter(body: '{}', statusCode: 429);
      final service = _buildService(adapter);

      await expectLater(
        service.chat(system: 's', user: 'u'),
        throwsA(isA<LlmException>()
            .having((e) => e.type, 'type', LlmErrorType.rateLimit)),
      );
    });

    test('500 抛 LlmException(badResponse)', () async {
      final adapter = _FakeAdapter(body: '{}', statusCode: 500);
      final service = _buildService(adapter);

      await expectLater(
        service.chat(system: 's', user: 'u'),
        throwsA(isA<LlmException>()
            .having((e) => e.type, 'type', LlmErrorType.badResponse)),
      );
    });

    test('连接异常抛 LlmException(network)', () async {
      final adapter = _FakeAdapter(
        error: const SocketException('Connection refused'),
      );
      final service = _buildService(adapter);

      await expectLater(
        service.chat(system: 's', user: 'u'),
        throwsA(isA<LlmException>()
            .having((e) => e.type, 'type', LlmErrorType.network)),
      );
    });

    test('响应缺 choices 抛 LlmException(badResponse)', () async {
      final adapter = _FakeAdapter(body: '{"foo":"bar"}');
      final service = _buildService(adapter);

      await expectLater(
        service.chat(system: 's', user: 'u'),
        throwsA(isA<LlmException>()
            .having((e) => e.type, 'type', LlmErrorType.badResponse)),
      );
    });
  });

  group('tryParseJsonObject', () {
    test('提取 ```json 围栏块', () {
      expect(
        LlmService.tryParseJsonObject('说明文字\n```json\n{"a":1}\n```\n结束'),
        {'a': 1},
      );
    });

    test('提取裸 JSON 对象', () {
      expect(LlmService.tryParseJsonObject('{"a":1}'), {'a': 1});
    });

    test('前后有其他文字时取首个 { 到末个 }', () {
      expect(
        LlmService.tryParseJsonObject('结果如下 {"a":1,"b":{"c":2}} 完毕'),
        {'a': 1, 'b': {'c': 2}},
      );
    });

    test('无 JSON 返回 null', () {
      expect(LlmService.tryParseJsonObject('abc'), isNull);
    });

    test('JSON 非法返回 null', () {
      expect(LlmService.tryParseJsonObject('{"a":}'), isNull);
    });
  });
}
