import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:opentrack/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late StorageService storage;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    storage = StorageService();
  });

  group('LLM 配置默认值', () {
    test('getLlmEnabled 默认返回 false', () async {
      expect(await storage.getLlmEnabled(), false);
    });

    test('getLlmBaseUrl 默认返回 DeepSeek 地址', () async {
      expect(await storage.getLlmBaseUrl(), 'https://api.deepseek.com/v1');
    });

    test('getLlmModel 默认返回 deepseek-chat', () async {
      expect(await storage.getLlmModel(), 'deepseek-chat');
    });

    test('getLlmApiKey 默认返回空字符串', () async {
      expect(await storage.getLlmApiKey(), '');
    });
  });

  group('LLM 缓存存取', () {
    test('setLlmAddressMap 后 getLlmAddressMap 原样返回', () async {
      const map = {'长春理工南区菜鸟驿站': '长春理工大学南区菜鸟驿站'};
      await storage.setLlmAddressMap(map);
      expect(await storage.getLlmAddressMap(), map);
    });

    test('setLlmEtaCache 后 getLlmEtaCache 原样返回', () async {
      const cache = {
        'h1': {'estimate': '预计10月20日前后送达', 'reason': '干线运输中'}
      };
      await storage.setLlmEtaCache(cache);
      expect(await storage.getLlmEtaCache(), cache);
    });
  });
}
