import 'package:flutter_test/flutter_test.dart';
import 'package:opentrack/services/llm_service.dart';
import 'package:opentrack/services/storage_service.dart';
import 'package:opentrack/utils/address_normalizer.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 记录 setLlmAddressMap 调用次数的 StorageService，其余行为不变
class _RecordingStorage extends StorageService {
  int setCalls = 0;

  @override
  Future<void> setLlmAddressMap(Map<String, String> map) async {
    setCalls++;
    await super.setLlmAddressMap(map);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _RecordingStorage storage;
  late LlmService llm;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    storage = _RecordingStorage();
    // bulkQuery 钩子被注入时不会真正调用网络，这里只需构造出实例
    llm = LlmService(baseUrl: 'http://localhost', model: 'test', apiKey: 'k');
  });

  group('LlmAddressNormalizer', () {
    test('缓存已有条目时不调用 bulkQuery，直接返回', () async {
      await storage.setLlmAddressMap({
        '长春理工南区菜鸟驿站': '长春理工大学南区菜鸟驿站',
      });
      storage.setCalls = 0;

      var bulkCalls = 0;
      final normalizer = LlmAddressNormalizer(
        llm: llm,
        storage: storage,
        bulkQuery: (addresses) async {
          bulkCalls++;
          return '{}';
        },
      );

      final result = await normalizer.normalizeAll(['长春理工南区菜鸟驿站']);

      expect(result, {'长春理工南区菜鸟驿站': '长春理工大学南区菜鸟驿站'});
      expect(bulkCalls, 0);
    });

    test('未命中地址批量调用一次 bulkQuery，返回映射与缓存合并后写入 storage', () async {
      await storage.setLlmAddressMap({
        '长春理工南区菜鸟驿站': '长春理工大学南区菜鸟驿站',
      });
      storage.setCalls = 0;

      var bulkCalls = 0;
      List<String>? queried;
      final normalizer = LlmAddressNormalizer(
        llm: llm,
        storage: storage,
        bulkQuery: (addresses) async {
          bulkCalls++;
          queried = addresses;
          return '{"长春理工大学南校区服务站":"长春理工大学南校区服务站",'
              '"重庆市渝北区龙兴菜鸟驿站":"重庆龙兴菜鸟驿站"}';
        },
      );

      final result = await normalizer.normalizeAll([
        '长春理工南区菜鸟驿站',
        '长春理工大学南校区服务站',
        '重庆市渝北区龙兴菜鸟驿站',
      ]);

      expect(bulkCalls, 1);
      expect(queried, ['长春理工大学南校区服务站', '重庆市渝北区龙兴菜鸟驿站']);
      expect(result, {
        '长春理工南区菜鸟驿站': '长春理工大学南区菜鸟驿站',
        '长春理工大学南校区服务站': '长春理工大学南校区服务站',
        '重庆市渝北区龙兴菜鸟驿站': '重庆龙兴菜鸟驿站',
      });
      // 缓存已有条目 + 本次返回条目合并写入
      expect(storage.setCalls, 1);
      expect(await storage.getLlmAddressMap(), {
        '长春理工南区菜鸟驿站': '长春理工大学南区菜鸟驿站',
        '长春理工大学南校区服务站': '长春理工大学南校区服务站',
        '重庆市渝北区龙兴菜鸟驿站': '重庆龙兴菜鸟驿站',
      });
    });

    test('bulkQuery 抛异常时未命中原样返回，且不写缓存', () async {
      await storage.setLlmAddressMap({
        '长春理工南区菜鸟驿站': '长春理工大学南区菜鸟驿站',
      });
      storage.setCalls = 0;

      final normalizer = LlmAddressNormalizer(
        llm: llm,
        storage: storage,
        bulkQuery: (addresses) async => throw Exception('网络失败'),
      );

      final result = await normalizer.normalizeAll([
        '长春理工南区菜鸟驿站',
        '重庆市渝北区龙兴菜鸟驿站',
      ]);

      expect(result, {
        '长春理工南区菜鸟驿站': '长春理工大学南区菜鸟驿站',
        '重庆市渝北区龙兴菜鸟驿站': '重庆市渝北区龙兴菜鸟驿站',
      });
      expect(storage.setCalls, 0);
    });

    test('bulkQuery 返回脏 JSON 时不写缓存，未命中原样返回', () async {
      final normalizer = LlmAddressNormalizer(
        llm: llm,
        storage: storage,
        bulkQuery: (addresses) async => '抱歉，我无法处理这个请求',
      );

      final result = await normalizer.normalizeAll([
        '长春理工南区菜鸟驿站',
        '重庆市渝北区龙兴菜鸟驿站',
      ]);

      expect(result, {
        '长春理工南区菜鸟驿站': '长春理工南区菜鸟驿站',
        '重庆市渝北区龙兴菜鸟驿站': '重庆市渝北区龙兴菜鸟驿站',
      });
      expect(storage.setCalls, 0);
      expect(await storage.getLlmAddressMap(), isEmpty);
    });

    test('LLM 返回的无关键（输入之外的地址）不进缓存', () async {
      final normalizer = LlmAddressNormalizer(
        llm: llm,
        storage: storage,
        bulkQuery: (addresses) async {
          return '{"长春理工南区菜鸟驿站":"长春理工大学南区菜鸟驿站",'
              '"输入之外的驿站":"不该写入缓存"}';
        },
      );

      final result = await normalizer.normalizeAll(['长春理工南区菜鸟驿站']);

      expect(result, {'长春理工南区菜鸟驿站': '长春理工大学南区菜鸟驿站'});
      expect(await storage.getLlmAddressMap(),
          {'长春理工南区菜鸟驿站': '长春理工大学南区菜鸟驿站'});
    });

    test('LLM 返回的非字符串或空值条目不进缓存', () async {
      final normalizer = LlmAddressNormalizer(
        llm: llm,
        storage: storage,
        bulkQuery: (addresses) async {
          return '{"长春理工南区菜鸟驿站":123,"重庆市渝北区龙兴菜鸟驿站":""}';
        },
      );

      final result = await normalizer.normalizeAll([
        '长春理工南区菜鸟驿站',
        '重庆市渝北区龙兴菜鸟驿站',
      ]);

      expect(result, {
        '长春理工南区菜鸟驿站': '长春理工南区菜鸟驿站',
        '重庆市渝北区龙兴菜鸟驿站': '重庆市渝北区龙兴菜鸟驿站',
      });
      // 无效条目被过滤后不进缓存
      expect(await storage.getLlmAddressMap(), isEmpty);
    });
  });
}
