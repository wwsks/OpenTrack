# 取件码助手 Flutter 实现指导

> 本文档指导你在 Flutter 应用中实现三个核心功能：**短信识别取件码**、**跳转淘宝身份码**、**跳转拼多多身份码**。
> 参考项目为原生 Android Kotlin 实现（`e:\reference\parcel`），以下内容将 Kotlin 逻辑翻译为 Flutter 等价实现。

---

## 一、整体架构

```
lib/
├── model/
│   ├── sms_model.dart          # 原始短信数据
│   ├── sms_data.dart           # 解析后的取件码数据
│   └── parcel_data.dart        # 按地址分组的包裹数据
├── util/
│   ├── sms_util.dart           # 读取系统短信
│   ├── sms_parser.dart         # 正则解析引擎（核心）
│   └── sms_processor.dart      # 加载 + 解析 + 分组编排
├── service/
│   ├── sms_receiver.dart       # 短信广播监听（平台通道）
│   └── sms_sync_service.dart   # 前台服务触发刷新
├── screen/
│   └── home_screen.dart        # 主页 + 淘宝/拼多多身份码菜单
└── main.dart
```

---

## 二、功能一：短信识别取件码

### 2.1 数据模型

#### `lib/model/sms_model.dart`

```dart
class SmsModel {
  final String id;       // 系统短信的 _id，或自定义短信的时间戳
  final String body;     // 短信原文
  final int timestamp;   // 毫秒时间戳

  SmsModel({required this.id, required this.body, required this.timestamp});

  Map<String, dynamic> toJson() => {'id': id, 'body': body, 'timestamp': timestamp};
  factory SmsModel.fromJson(Map<String, dynamic> json) =>
      SmsModel(id: json['id'], body: json['body'], timestamp: json['timestamp']);
}
```

#### `lib/model/sms_data.dart`

```dart
class SmsData {
  final String address;       // 提取的地址（如"3号丰巢柜"）
  final String code;          // 提取的取件码，多个用逗号分隔
  final SmsModel sms;         // 原始短信引用
  final String id;            // 组合键："${sms.id}_${sms.timestamp}"
  bool isCompleted;           // 是否已取件
  final String lockerNumber;  // 柜号数字（如"3"）

  SmsData({
    required this.address,
    required this.code,
    required this.sms,
    required this.id,
    this.isCompleted = false,
    this.lockerNumber = '',
  });
}
```

#### `lib/model/parcel_data.dart`

```dart
class ParcelData {
  final String address;              // 分组地址（可能是标签）
  final List<SmsData> smsDataList;   // 该地址下的所有短信
  int num;                           // 未取件的取件码数量

  ParcelData({required this.address, required this.smsDataList, this.num = 0});
}
```

### 2.2 读取系统短信

#### `lib/util/sms_util.dart`

**依赖**：在 `pubspec.yaml` 中添加：

```yaml
dependencies:
  telephony: ^0.2.0+1   # 用于读取系统短信和监听短信广播
```

**注意**：`telephony` 插件需要 Android 原生权限，需在 `AndroidManifest.xml` 中声明。

```dart
import 'package:telephony/telephony.dart';
import '../model/sms_model.dart';

class SmsUtil {
  static final Telephony _telephony = Telephony.instance;

  /// 读取系统收件箱短信
  /// [daysFilter] 读取最近几天的短信，0表示全部
  static Future<List<SmsModel>> readSmsByTimeFilter(int daysFilter) async {
    List<SmsMessage> messages;

    if (daysFilter > 0) {
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day)
          .subtract(Duration(days: daysFilter - 1));
      final startTime = startOfDay.millisecondsSinceEpoch;

      messages = await _telephony.getInboxSms(
        columns: [SmsColumn.ID, SmsColumn.BODY, SmsColumn.DATE],
        filter: SmsFilter.where(SmsColumn.DATE).greaterThan(startTime.toString()),
        sortOrder: [OrderBy(SmsColumn.DATE, sort: Sort.DESC)],
      );
    } else {
      messages = await _telephony.getInboxSms(
        columns: [SmsColumn.ID, SmsColumn.BODY, SmsColumn.DATE],
        sortOrder: [OrderBy(SmsColumn.DATE, sort: Sort.DESC)],
      );
    }

    return messages.map((m) => SmsModel(
      id: (m.id ?? 0).toString(),
      body: m.body ?? '',
      timestamp: m.date ?? 0,
    )).toList();
  }

  /// 格式化取件码显示（长数字每4位加空格）
  static String formatPickupCode(String code) {
    return code.split(',').map((singleCode) {
      final trimmed = singleCode.trim();
      if (trimmed.contains('-')) return trimmed;
      final digitsOnly = trimmed.replaceAll(RegExp(r'[^\d]'), '');
      if (digitsOnly.length >= 8) {
        return digitsOnly.replaceAllMapped(
          RegExp(r'.{4}'), (m) => '${m.group(0)} ',
        ).trim();
      }
      return digitsOnly;
    }).join(', ');
  }

  /// 判断两个时间戳是否在同一天
  static bool isSameDay(int ts1, int ts2) {
    final d1 = DateTime.fromMillisecondsSinceEpoch(ts1);
    final d2 = DateTime.fromMillisecondsSinceEpoch(ts2);
    return d1.year == d2.year && d1.day == d2.day;
  }
}
```

### 2.3 短信广播监听（新短信到达时自动触发）

#### `lib/service/sms_receiver.dart`

**原理**：通过 Flutter 的 `MethodChannel` 监听 Android 原生的 `SMS_RECEIVED` 广播。

**步骤 1 — Android 原生端注册 BroadcastReceiver**

在 `android/app/src/main/kotlin/.../` 下创建 `SmsReceiver.kt`：

```kotlin
package com.yourpackage.xxx

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel

class SmsReceiver : BroadcastReceiver() {
    companion object {
        var eventSink: EventChannel.EventSink? = null
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == "android.provider.Telephony.SMS_RECEIVED") {
            // 通知 Flutter 层有新短信到达
            // Flutter 端收到事件后延迟1.5秒再读取短信（等待系统写入数据库）
            eventSink?.success("new_sms")
        }
    }
}
```

在 `MainActivity.kt` 中注册 EventChannel：

```kotlin
package com.yourpackage.xxx

import android.content.IntentFilter
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.EventChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.yourpackage.xxx/sms_events"
    private var smsReceiver: SmsReceiver? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // 注册短信广播接收器
        smsReceiver = SmsReceiver()
        val filter = IntentFilter("android.provider.Telephony.SMS_RECEIVED")
        filter.priority = 999
        registerReceiver(smsReceiver, filter)

        // 注册 EventChannel
        flutterEngine?.dartExecutor?.binaryMessenger?.let { messenger ->
            EventChannel(messenger, CHANNEL).setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    SmsReceiver.eventSink = events
                }
                override fun onCancel(arguments: Any?) {
                    SmsReceiver.eventSink = null
                }
            })
        }
    }

    override fun onDestroy() {
        smsReceiver?.let { unregisterReceiver(it) }
        super.onDestroy()
    }
}
```

**步骤 2 — Flutter 端监听事件**

```dart
import 'package:flutter/services.dart';

class SmsEventService {
  static const _channel = EventChannel('com.yourpackage.xxx/sms_events');

  /// 监听新短信事件流，收到事件后延迟1.5秒再通知（等待系统写入短信数据库）
  static Stream<void> get onNewSms async* {
    await for (final _ in _channel.receiveBroadcastStream()) {
      await Future.delayed(const Duration(milliseconds: 1500));
      yield null;
    }
  }
}
```

**步骤 3 — AndroidManifest.xml 权限**

```xml
<uses-permission android:name="android.permission.RECEIVE_SMS" />
<uses-permission android:name="android.permission.READ_SMS" />

<receiver android:name=".SmsReceiver" android:exported="true">
    <intent-filter android:priority="999">
        <action android:name="android.provider.Telephony.SMS_RECEIVED" />
    </intent-filter>
</receiver>
```

### 2.4 核心解析引擎（正则）

#### `lib/util/sms_parser.dart`

**这是整个功能的核心。** 完整翻译自原项目的 `SmsParser.kt`。

```dart
import 'dart:core';

class ParseResult {
  final String address;
  final String code;
  final String lockerNumber;
  final bool success;

  ParseResult({
    required this.address,
    required this.code,
    required this.lockerNumber,
    required this.success,
  });
}

class SmsParser {
  /// 是否优先匹配快递柜地址
  bool preferLockerAddress = true;

  // ===== 内置正则 =====

  /// 匹配柜号：如 "3号柜"、"15号丰巢柜"
  /// 捕获组1 = 数字
  static final RegExp lockerPattern = RegExp(
    r'([0-9]+)号(?:柜|快递柜|丰巢柜|蜂巢柜|熊猫柜|兔喜快递柜)',
    caseSensitive: false,
  );

  /// 匹配地址关键词后的内容
  static final RegExp addressPattern = RegExp(
    r'(地址|收货地址|送货地址|位于|放至|已到达|到达|已到|送达|到|已放入|已存放至|已存放|放入)'
    r'[\s\S]*?'
    r'([\w\s-]+?(?:门牌|驿站|快递点|门面|柜|,|，|。|$))',
    caseSensitive: false,
  );

  /// 匹配取件码：关键词 + 2个以上字母数字字符，支持多个逗号分隔的码
  static final RegExp codePattern = RegExp(
    r'(请用|取件码为|提货号为|取货码为|提货码为'
    r'|取件码（|提货号（|取货码（|提货码（'
    r'|取件码『|提货号『|取货码『|提货码『'
    r'|取件码【|提货号【|取货码【|提货码【'
    r'|取件码\(|提货号\(|取货码\(|提货码\('
    r'|取件码\[|提货号\[|取货码\[|提货码\['
    r'|取件码|提货号|取货码|提货码'
    r'|凭|快递|京东|天猫|中通|顺丰|韵达|德邦|菜鸟|拼多多|EMS|闪送|美团|饿了么|盒马|叮咚买菜|UU跑腿'
    r'|签收码|签收编号|操作码|提货编码|收货编码|签收编码'
    r'|取件編號|提貨號碼|運單碼|快遞碼|快件碼|包裹碼|貨品碼'
    r')\s*[A-Za-z0-9\s-]{2,}(?:[，,、][A-Za-z0-9\s-]{2,})*',
    caseSensitive: false,
  );

  // ===== 自定义规则 =====
  final List<String> customAddressPatterns = [];
  final List<RegExp> customCodePatterns = [];
  final List<String> ignoreKeywords = [];

  void addCustomAddressPattern(String pattern) {
    customAddressPatterns.add(pattern);
  }

  void addCustomCodePattern(String pattern) {
    customCodePatterns.add(RegExp(pattern));
  }

  void addIgnoreKeyword(String keyword) {
    if (keyword.trim().isNotEmpty && !ignoreKeywords.contains(keyword)) {
      ignoreKeywords.add(keyword);
    }
  }

  void clearAllCustomPatterns() {
    customAddressPatterns.clear();
    customCodePatterns.clear();
    ignoreKeywords.clear();
  }

  // ===== 核心解析方法 =====

  ParseResult parseSms(String sms) {
    String foundAddress = '';
    String foundCode = '';

    // Step 1: 检查忽略关键词
    for (final keyword in ignoreKeywords) {
      if (keyword.trim().isNotEmpty &&
          sms.toLowerCase().contains(keyword.toLowerCase())) {
        return ParseResult(address: '', code: '', lockerNumber: '', success: false);
      }
    }

    // Step 2: 尝试自定义规则（优先级最高）
    for (final pattern in customAddressPatterns) {
      if (sms.toLowerCase().contains(pattern.toLowerCase())) {
        foundAddress = pattern;
        break;
      }
    }
    for (final pattern in customCodePatterns) {
      final match = pattern.firstMatch(sms);
      if (match != null) {
        foundCode = match.group(1) ?? '';
        break;
      }
    }

    // Step 3: 如果自定义规则没命中，使用内置规则提取地址
    if (foundAddress.isEmpty) {
      if (preferLockerAddress) {
        final lockerMatch = lockerPattern.firstMatch(sms);
        if (lockerMatch != null) {
          foundAddress = lockerMatch.group(0) ?? '';
        }
      }
      if (foundAddress.isEmpty) {
        // 取所有匹配中最长的地址
        String longestAddress = '';
        for (final match in addressPattern.allMatches(sms)) {
          final current = match.group(2) ?? '';
          if (current.length > longestAddress.length) {
            longestAddress = current;
          }
        }
        foundAddress = longestAddress;
      }
    }

    // Step 4: 始终提取柜号数字
    final lockerMatch = lockerPattern.firstMatch(sms);
    final lockerNumber = lockerMatch?.group(1) ?? '';

    // Step 5: 如果自定义规则没提取到码，使用内置正则
    if (foundCode.isEmpty) {
      Match? lastMatch;
      for (final match in codePattern.allMatches(sms)) {
        lastMatch = match;
      }
      if (lastMatch != null) {
        final rawMatch = lastMatch.group(0) ?? '';
        // 按逗号/顿号拆分多个取件码
        final codes = rawMatch.split(RegExp(r'[，,、]'));
        foundCode = codes.map((c) => c.trim()).join(', ');
        // 移除非字母数字字符（保留逗号、横杠、空格）
        foundCode = foundCode.replaceAll(RegExp(r'[^A-Za-z0-9-, ]'), '');
      }
    }

    // Step 6: 清理地址
    foundAddress = foundAddress.replaceAll(RegExp(r'[，,。]'), '');
    foundAddress = foundAddress.replaceAll('取件', '');

    return ParseResult(
      address: foundAddress,
      code: foundCode,
      lockerNumber: lockerNumber,
      success: foundAddress.isNotEmpty && foundCode.isNotEmpty,
    );
  }
}
```

### 2.5 加载与分组编排

#### `lib/util/sms_processor.dart`

```dart
import '../model/sms_model.dart';
import '../model/sms_data.dart';
import '../model/parcel_data.dart';
import 'sms_parser.dart';
import 'sms_util.dart';

class ProcessResult {
  final List<SmsData> successful;
  final List<ParcelData> parcels;
  final List<SmsModel> failed;

  ProcessResult(this.successful, this.parcels, this.failed);
}

class SmsProcessor {
  /// 加载系统短信 + 自定义短信，合并后解析
  static Future<ProcessResult> loadAndProcess({
    required int daysFilter,
    required SmsParser parser,
    required List<String> completedIds,
    required Future<List<SmsModel>> Function() loadCustomSms,
    Map<String, String> addressMappings = const {},
  }) async {
    final systemSms = await SmsUtil.readSmsByTimeFilter(daysFilter);
    final customSms = await loadCustomSms();
    final mergedList = [...systemSms, ...customSms];
    return process(mergedList, parser, completedIds, addressMappings);
  }

  /// 核心处理：解析 + 分组 + 去重 + 排序
  static ProcessResult process(
    List<SmsModel> messages,
    SmsParser parser,
    List<String> completedIds,
    Map<String, String> addressMappings,
  ) {
    final successful = <SmsData>[];
    final parcelsMap = <String, ParcelData>{};
    final failed = <SmsModel>[];

    for (final sms in messages) {
      final result = parser.parseSms(sms.body);

      if (result.success) {
        final combinedKey = '${sms.id}_${sms.timestamp}';
        final originalAddress = result.address;
        final groupAddress = addressMappings[originalAddress] ?? originalAddress;

        final smsData = SmsData(
          address: originalAddress,
          code: result.code,
          sms: sms,
          id: combinedKey,
          lockerNumber: result.lockerNumber,
        );
        successful.add(smsData);

        // 按地址分组，同一天同地址同码的去重
        final existingParcel = parcelsMap[groupAddress];
        if (existingParcel != null) {
          final isDuplicate = existingParcel.smsDataList.any((existing) =>
            existing.address == smsData.address &&
            existing.code == smsData.code &&
            SmsUtil.isSameDay(existing.sms.timestamp, smsData.sms.timestamp),
          );
          if (!isDuplicate) {
            existingParcel.smsDataList.add(smsData);
          }
        } else {
          parcelsMap[groupAddress] = ParcelData(
            address: groupAddress,
            smsDataList: [smsData],
          );
        }
      } else {
        failed.add(sms);
      }
    }

    // 按时间倒序
    successful.sort((a, b) => b.sms.timestamp.compareTo(a.sms.timestamp));
    failed.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    // 每组内排序：有柜号的排前面，按柜号升序
    for (final parcel in parcelsMap.values) {
      parcel.smsDataList.sort((a, b) {
        // 无柜号的排后面
        if (a.lockerNumber.isEmpty && b.lockerNumber.isNotEmpty) return 1;
        if (a.lockerNumber.isNotEmpty && b.lockerNumber.isEmpty) return -1;
        // 按柜号数字升序
        final aNum = int.tryParse(a.lockerNumber) ?? 999999;
        final bNum = int.tryParse(b.lockerNumber) ?? 999999;
        if (aNum != bNum) return aNum.compareTo(bNum);
        // 最后按码排序
        return a.code.compareTo(b.code);
      });
    }

    // 计算完成状态和未取件数量
    final completedIdsSet = completedIds.toSet();
    final parcels = parcelsMap.values.map((parcel) {
      final newList = parcel.smsDataList.map((smsData) {
        final combinedKey = '${smsData.sms.id}_${smsData.sms.timestamp}';
        final isCompleted = completedIdsSet.contains(combinedKey) ||
            completedIdsSet.contains(smsData.sms.id);
        return SmsData(
          address: smsData.address,
          code: smsData.code,
          sms: smsData.sms,
          id: smsData.id,
          isCompleted: isCompleted,
          lockerNumber: smsData.lockerNumber,
        );
      }).toList();

      final uncompletedNum = newList
          .where((s) => !s.isCompleted)
          .fold(0, (sum, s) => sum + s.code.split(', ').length);

      return ParcelData(
        address: parcel.address,
        smsDataList: newList,
        num: uncompletedNum,
      );
    }).toList();

    // 有未取件的排前面，然后按地址字母序
    parcels.sort((a, b) {
      final aHas = a.num > 0 ? 0 : 1;
      final bHas = b.num > 0 ? 0 : 1;
      if (aHas != bHas) return aHas.compareTo(bHas);
      return a.address.compareTo(b.address);
    });

    return ProcessResult(successful, parcels, failed);
  }
}
```

### 2.6 持久化（SharedPreferences）

在 `pubspec.yaml` 中添加：

```yaml
dependencies:
  shared_preferences: ^2.2.0
  json_annotation: ^4.8.1
```

关键存储逻辑（参考原项目 `save_data.kt`）：

```dart
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class SaveData {
  /// 保存/读取自定义短信列表
  static Future<void> addCustomSms(SmsModel sms) async {
    final prefs = await SharedPreferences.getInstance();
    final list = await getCustomSmsList();
    list.add(sms);
    final json = jsonEncode(list.map((s) => s.toJson()).toList());
    await prefs.setString('custom_sms_list', json);
  }

  static Future<List<SmsModel>> getCustomSmsList() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString('custom_sms_list') ?? '[]';
    final list = jsonDecode(json) as List;
    return list.map((s) => SmsModel.fromJson(s)).toList();
  }

  /// 保存/读取已完成的取件码ID
  static Future<void> addCompletedId(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final set = prefs.getStringList('completedIds')?.toSet() ?? {};
    set.add(id);
    await prefs.setStringList('completedIds', set.toList());
  }

  static Future<List<String>> getCompletedIds() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList('completedIds') ?? [];
  }

  /// 保存/读取自定义规则
  static Future<void> addCustomPattern(String key, String pattern) async {
    final prefs = await SharedPreferences.getInstance();
    final set = prefs.getStringList(key)?.toSet() ?? {};
    set.add(pattern);
    await prefs.setStringList(key, set.toList());
  }

  static Future<Set<String>> getCustomPatterns(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(key)?.toSet() ?? {};
  }

  /// 保存/读取忽略关键词
  static Future<void> addIgnoreKeyword(String keyword) async {
    final prefs = await SharedPreferences.getInstance();
    final set = prefs.getStringList('ignoreKeywords')?.toSet() ?? {};
    set.add(keyword);
    await prefs.setStringList('ignoreKeywords', set.toList());
  }

  static Future<Set<String>> getIgnoreKeywords() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList('ignoreKeywords')?.toSet() ?? {};
  }

  /// 保存/读取时间过滤天数索引
  static Future<void> saveTimeFilterIndex(int index) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('timeFilterIndex', index);
  }

  static Future<int> getTimeFilterIndex() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('timeFilterIndex') ?? 3;
  }

  /// 地址映射（地址标签）
  static Future<void> saveAddressMapping(String original, String tag) async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString('address_mappings_json') ?? '[]';
    final list = (jsonDecode(json) as List).cast<Map<String, dynamic>>();
    list.removeWhere((m) => m['originalAddress'] == original);
    list.add({'originalAddress': original, 'tag': tag});
    await prefs.setString('address_mappings_json', jsonEncode(list));
  }

  static Future<Map<String, String>> getAddressMappings() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString('address_mappings_json') ?? '[]';
    final list = (jsonDecode(json) as List).cast<Map<String, dynamic>>();
    return {for (final m in list) m['originalAddress'] as String: m['tag'] as String};
  }
}
```

### 2.7 初始化流程（在 main.dart 或首页 initState 中）

```dart
// 1. 加载自定义规则到 parser
final parser = SmsParser();
final addressPatterns = await SaveData.getCustomPatterns('address');
final codePatterns = await SaveData.getCustomPatterns('code');
final ignoreKeywords = await SaveData.getIgnoreKeywords();

for (final p in addressPatterns) { parser.addCustomAddressPattern(p); }
for (final p in codePatterns) { parser.addCustomCodePattern(p); }
for (final k in ignoreKeywords) { parser.addIgnoreKeyword(k); }

// 2. 加载已完成ID
final completedIds = await SaveData.getCompletedIds();

// 3. 加载地址映射
final addressMappings = await SaveData.getAddressMappings();

// 4. 处理
final result = await SmsProcessor.loadAndProcess(
  daysFilter: 7,
  parser: parser,
  completedIds: completedIds,
  loadCustomSms: SaveData.getCustomSmsList,
  addressMappings: addressMappings,
);

// result.parcels 就是按地址分组的取件码列表
```

### 2.8 支持的快递公司和关键词一览

| 类别 | 关键词 |
|------|--------|
| 取件码相关 | 取件码、提货号、取货码、提货码、签收码、签收编号、操作码、提货编码、收货编码、签收编码、请用、凭 |
| 快递公司 | 京东、天猫、中通、顺丰、韵达、德邦、菜鸟、拼多多、EMS |
| 即时配送 | 闪送、美团、饿了么、盒马、叮咚买菜、UU跑腿 |
| 快递柜 | 丰巢柜、蜂巢柜、熊猫柜、兔喜快递柜 |
| 繁体中文 | 取件編號、提貨號碼、運單碼、快遞碼、快件碼、包裹碼、貨品碼 |
| 地址关键词 | 地址、收货地址、送货地址、位于、放至、已到达、到达、已到、送达、已放入、已存放至、已存放、放入 |

---

## 三、功能二：跳转淘宝身份码

### 3.1 功能说明

淘宝身份码是一个在淘宝 App 内显示的二维码，用户在快递驿站取件时出示给工作人员扫描。本功能**不存储也不生成二维码**，只提供一个快捷入口，通过 deep link 跳转到淘宝 App 的身份码页面。

### 3.2 Flutter 实现

#### 依赖

```yaml
dependencies:
  url_launcher: ^6.1.0
```

#### 代码

```dart
import 'package:url_launcher/url_launcher.dart';

/// 跳转淘宝身份码页面
/// 返回 true 表示成功跳转，false 表示淘宝未安装或跳转失败
Future<bool> openTaobaoIdentityCode() async {
  const pkg = 'com.taobao.taobao';
  const lastmile =
      'https://pages-fast.m.taobao.com/wow/z/uniapp/1100333/last-mile-fe/m-end-school-tab/home';

  // 方案1：使用淘宝的 tbopen:// 自定义 scheme 跳转
  // 这是淘宝注册的 deeplink 协议，能直接打开淘宝 App 内的 H5 页面
  final tbopenUrl = 'tbopen://m.taobao.com/tbopen/index.html?h5Url=${Uri.encodeComponent(lastmile)}';

  try {
    final uri = Uri.parse(tbopenUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return true;
    }
  } catch (_) {}

  // 方案2：直接用 HTTPS URL，系统会尝试用淘宝打开
  try {
    final uri = Uri.parse(lastmile);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return true;
    }
  } catch (_) {}

  // 方案3：尝试通用 scheme 跳转到淘宝首页（用户可手动找到身份码入口）
  try {
    final uri = Uri.parse('taobao://');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return true;
    }
  } catch (_) {}

  return false;
}
```

### 3.3 跳转策略说明

| 优先级 | URL | 说明 |
|--------|-----|------|
| 1 | `tbopen://m.taobao.com/tbopen/index.html?h5Url=<编码后的H5地址>` | 淘宝专用 deeplink，直接打开"最后一公里"取件页面 |
| 2 | `https://pages-fast.m.taobao.com/...` | HTTPS 链接，系统可能用淘宝打开 |
| 3 | `taobao://` | 淘宝通用 scheme，打开淘宝首页 |

### 3.4 UI 放置位置

参考原项目，在主页的 **右上角更多菜单（三点图标）** 中添加一个 `PopupMenuItem` 或 `DropdownMenuItem`：

```dart
PopupMenuButton<String>(
  onSelected: (value) async {
    if (value == 'taobao_code') {
      final success = await openTaobaoIdentityCode();
      if (!success && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('无法打开淘宝，请确认已安装淘宝App')),
        );
      }
    }
  },
  itemBuilder: (context) => [
    const PopupMenuItem(value: 'taobao_code', child: Text('淘宝身份码')),
    // ... 其他菜单项
  ],
)
```

---

## 四、功能三：跳转拼多多身份码

### 4.1 功能说明

与淘宝身份码类似，拼多多身份码是拼多多 App 内用于取件的二维码。本功能通过 deep link 跳转到拼多多的取件页面。

### 4.2 Flutter 实现

```dart
import 'package:url_launcher/url_launcher.dart';

/// 跳转拼多多身份码/取件页面
/// 返回 true 表示成功跳转，false 表示拼多多未安装或跳转失败
Future<bool> openPddIdentityCode() async {
  const pkg = 'com.xunmeng.pinduoduo';

  // 按优先级尝试多个 deeplink scheme
  final schemes = [
    'pinduoduo://com.xunmeng.pinduoduo/mdkd/package',  // 取件/身份码页面
    'pinduoduo://com.xunmeng.pinduoduo/',               // 拼多多首页
    'pinduoduo://',                                       // 通用 scheme
  ];

  for (final scheme in schemes) {
    try {
      final uri = Uri.parse(scheme);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return true;
      }
    } catch (_) {}
  }

  // 最后兜底：尝试直接启动拼多多 App
  try {
    final uri = Uri.parse('market://details?id=$pkg');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return true;
    }
  } catch (_) {}

  return false;
}
```

### 4.3 跳转策略说明

| 优先级 | URL | 说明 |
|--------|-----|------|
| 1 | `pinduoduo://com.xunmeng.pinduoduo/mdkd/package` | 直接跳转取件/身份码页面 |
| 2 | `pinduoduo://com.xunmeng.pinduoduo/` | 拼多多首页 |
| 3 | `pinduoduo://` | 通用 scheme |
| 4 | `market://details?id=com.xunmeng.pinduoduo` | 应用商店（兜底） |

### 4.4 UI 放置位置

与淘宝身份码放在同一个菜单中：

```dart
PopupMenuButton<String>(
  onSelected: (value) async {
    switch (value) {
      case 'taobao_code':
        // ... 淘宝逻辑
        break;
      case 'pdd_code':
        final success = await openPddIdentityCode();
        if (!success && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('无法打开拼多多，请确认已安装拼多多App')),
          );
        }
        break;
    }
  },
  itemBuilder: (context) => [
    const PopupMenuItem(value: 'taobao_code', child: Text('淘宝身份码')),
    const PopupMenuItem(value: 'pdd_code', child: Text('拼多多身份码')),
  ],
)
```

---

## 五、AndroidManifest.xml 所需权限汇总

```xml
<!-- 短信读取 -->
<uses-permission android:name="android.permission.RECEIVE_SMS" />
<uses-permission android:name="android.permission.READ_SMS" />

<!-- 前台服务（短信接收后触发刷新） -->
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_DATA_SYNC" />
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />

<!-- 跳转其他 App -->
<queries>
    <package android:name="com.taobao.taobao" />
    <package android:name="com.xunmeng.pinduoduo" />
    <intent>
        <action android:name="android.intent.action.VIEW" />
        <data android:scheme="tbopen" />
    </intent>
    <intent>
        <action android:name="android.intent.action.VIEW" />
        <data android:scheme="pinduoduo" />
    </intent>
    <intent>
        <action android:name="android.intent.action.VIEW" />
        <data android:scheme="market" />
    </intent>
</queries>
```

> **注意**：`<queries>` 标签在 Android 11+ (API 30+) 是必需的，用于声明你的 App 需要查询/启动哪些其他 App。如果不声明，`canLaunchUrl()` 会返回 false。

---

## 六、依赖汇总（pubspec.yaml）

```yaml
dependencies:
  flutter:
    sdk: flutter
  telephony: ^0.2.0+1          # 读取系统短信 + 短信广播
  url_launcher: ^6.1.0         # 跳转淘宝/拼多多
  shared_preferences: ^2.2.0   # 本地持久化存储
```

---

## 七、完整数据流图

```
新短信到达
    │
    ▼
SmsReceiver (Android BroadcastReceiver, priority=999)
    │
    ▼
EventChannel → Flutter 层收到事件
    │
    ▼
等待 1.5 秒（等系统写入短信数据库）
    │
    ▼
SmsUtil.readSmsByTimeFilter() 读取系统短信
    │
    ▼
SmsProcessor.loadAndProcess()
    ├── 读取系统短信 (content://sms/inbox)
    ├── 读取自定义短信 (SharedPreferences)
    ├── 合并列表
    └── 对每条短信调用 SmsParser.parseSms()
            ├── 检查忽略关键词
            ├── 尝试自定义规则
            ├── 提取地址（优先快递柜）
            ├── 提取取件码（正则匹配）
            └── 返回 ParseResult
    │
    ▼
分组 + 去重 + 排序 + 计算完成状态
    │
    ▼
UI 展示（按地址分组的取件码列表）
```

---

## 八、测试用例参考

以下是原项目中出现过的真实短信格式，用于验证解析正确性：

| 短信内容 | 期望地址 | 期望取件码 |
|----------|----------|-----------|
| `您的快递已到达菜鸟驿站3号柜，取件码为1234，请尽快取件` | 3号柜 | 1234 |
| `您有包裹已放入丰巢柜，5号柜，取件码5678` | 5号柜 | 5678 |
| `【顺丰速运】您的快递已送达，签收码 ABC123，请凭码取件` | (地址从上下文提取) | ABC123 |
| `京东快递：您的包裹已到达北京市朝阳区XX驿站，提货号为JD8888` | 北京市朝阳区XX驿站 | JD8888 |
| `菜鸟裹裹：取件码 1111, 2222 已到XX小区快递点` | XX小区快递点 | 1111, 2222 |
| `【中通快递】快递已放至3号丰巢柜，取件码【9999】` | 3号丰巢柜 | 9999 |

---

## 九、注意事项与常见陷阱

1. **短信权限**：Android 6.0+ 需要运行时权限申请 `READ_SMS` 和 `RECEIVE_SMS`。建议在首页 `initState` 中检查并申请。

2. **`telephony` 插件兼容性**：该插件仅支持 Android。iOS 不支持读取系统短信，需在 iOS 端做平台判断或禁用此功能。

3. **短信广播延迟**：收到 `SMS_RECEIVED` 广播时，短信可能还未写入系统数据库。原项目的做法是延迟 1.5 秒后再读取，Flutter 端应保持同样的延迟策略。

4. **`<queries>` 标签**：Android 11+ 必须在 `AndroidManifest.xml` 中声明要查询的包名和 scheme，否则 `canLaunchUrl()` 始终返回 false，跳转功能会静默失败。

5. **正则的 `(?i)` 标志**：Dart 的 `RegExp` 使用 `caseSensitive: false` 参数实现不区分大小写，等价于 Java/Kotlin 的 `Pattern.CASE_INSENSITIVE`。

6. **`codePattern` 的贪婪匹配**：原项目使用 `while (codeMatcher.find())` 并取最后一次匹配结果。Dart 端需要用 `allMatches()` 取最后一个 match，或者用 `RegExp.allMatches(sms).last`。

7. **地址清理**：原项目在最后会移除地址中的 `，` `，` `。` 标点和 `"取件"` 子串，务必保持一致。

8. **取件码后处理**：匹配到的码需要按 `，` `，` `、` 拆分，再用 `, ` 重新拼接，最后移除 `[^A-Za-z0-9-, ]` 之外的字符。
