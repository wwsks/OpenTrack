import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:opentrack/config/constants.dart';
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

  group('LLM 缓存脏数据降级', () {
    /// 直接写入原始字符串，模拟缓存被污染的场景
    Future<void> seedRaw(String key, String raw) async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, raw);
    }

    test('getLlmAddressMap 遇损坏 JSON 返回空 Map 不抛异常', () async {
      await seedRaw(AppConstants.keyLlmAddressMap, '{not-valid-json');
      expect(await storage.getLlmAddressMap(), isEmpty);
    });

    test('getLlmAddressMap 顶层非对象返回空 Map', () async {
      await seedRaw(AppConstants.keyLlmAddressMap, '["a","b"]');
      expect(await storage.getLlmAddressMap(), isEmpty);
    });

    test('getLlmAddressMap 过滤值非字符串的脏条目', () async {
      await seedRaw(
          AppConstants.keyLlmAddressMap, '{"a":"甲","b":123,"c":null}');
      expect(await storage.getLlmAddressMap(), {'a': '甲'});
    });

    test('getLlmEtaCache 遇损坏 JSON 返回空 Map 不抛异常', () async {
      await seedRaw(AppConstants.keyLlmEtaCache, 'oops');
      expect(await storage.getLlmEtaCache(), isEmpty);
    });

    test('getLlmEtaCache 过滤值非 Map 与 null 字段的脏条目', () async {
      await seedRaw(AppConstants.keyLlmEtaCache,
          '{"h1":{"estimate":null,"reason":"r"},"h2":"bad","h3":{"estimate":"e","reason":"r"}}');
      // null 字段被过滤（不产生 "null" 字符串穿透），值非 Map 的条目整条丢弃
      expect(await storage.getLlmEtaCache(), {
        'h1': {'reason': 'r'},
        'h3': {'estimate': 'e', 'reason': 'r'},
      });
    });
  });
}
