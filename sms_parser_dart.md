# SmsParser.kt → Dart 完整转换

> 将原项目 `SmsParser.kt` 的所有正则、自定义规则、解析算法逐行转换为 Dart 代码。

---

## 1. 数据类 `ParseResult`

```dart
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
```

---

## 2. 解析器 `SmsParser`

```dart
import 'dart:core';

class SmsParser {
  /// 是否优先匹配快递柜地址（对应原项目的 preferLockerAddress）
  bool preferLockerAddress = true;

  // ========================
  // 内置正则（从 SmsParser.kt 第12-18行直接转换）
  // ========================

  /// 柜号正则（原项目第12-13行）
  /// 匹配 "3号柜"、"15号丰巢柜" 等，捕获组1 = 数字
  static final RegExp _lockerPattern = RegExp(
    r'([0-9]+)号(?:柜|快递柜|丰巢柜|蜂巢柜|熊猫柜|兔喜快递柜)',
    caseSensitive: false,
  );

  /// 地址正则（原项目第14-15行）
  /// 捕获组1 = 地址引导词，捕获组2 = 地址内容
  static final RegExp _addressPattern = RegExp(
    r'(地址|收货地址|送货地址|位于|放至|已到达|到达|已到|送达|到|已放入|已存放至|已存放|放入)'
    r'[\s\S]*?'
    r'([\w\s-]+?(?:门牌|驿站|快递点|门面|柜|,|，|。|$))',
    caseSensitive: false,
  );

  /// 取件码正则（原项目第16-18行）
  /// 捕获组1 = 关键词，后续为取件码本体，支持多个逗号分隔的码
  static final RegExp _codePattern = RegExp(
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

  // ========================
  // 自定义规则（对应原项目第21-23行）
  // ========================

  /// 自定义地址模式：简单子串包含匹配
  /// 原项目：private val customAddressPatterns = mutableListOf<String>()
  final List<String> _customAddressPatterns = [];

  /// 自定义码模式：正则匹配，捕获组1 = 取件码
  /// 原项目：private val customCodePatterns = mutableListOf<Pattern>()
  final List<RegExp> _customCodePatterns = [];

  /// 忽略关键词：包含这些词的短信直接跳过不解析
  /// 原项目：private val ignoreKeywords = mutableListOf<String>()
  final List<String> _ignoreKeywords = [];

  // ========================
  // 自定义规则的增删方法（对应原项目第100-130行）
  // ========================

  /// 添加自定义地址模式
  /// 原项目：fun addCustomAddressPattern(pattern: String)
  void addCustomAddressPattern(String pattern) {
    _customAddressPatterns.add(pattern);
  }

  /// 添加自定义码模式（传入正则字符串）
  /// 原项目：fun addCustomCodePattern(pattern: String)
  void addCustomCodePattern(String pattern) {
    _customCodePatterns.add(RegExp(pattern));
  }

  /// 添加忽略关键词（去重，忽略空白）
  /// 原项目：fun addIgnoreKeyword(keyword: String)
  void addIgnoreKeyword(String keyword) {
    if (keyword.trim().isNotEmpty && !_ignoreKeywords.contains(keyword)) {
      _ignoreKeywords.add(keyword);
    }
  }

  /// 移除忽略关键词
  /// 原项目：fun removeIgnoreKeyword(keyword: String)
  void removeIgnoreKeyword(String keyword) {
    _ignoreKeywords.remove(keyword);
  }

  /// 获取忽略关键词列表（只读副本）
  /// 原项目：fun getIgnoreKeywords(): List<String>
  List<String> getIgnoreKeywords() => List.unmodifiable(_ignoreKeywords);

  /// 清除所有自定义规则（地址模式 + 码模式 + 忽略关键词）
  /// 原项目：fun clearAllCustomPatterns()
  void clearAllCustomPatterns() {
    _customAddressPatterns.clear();
    _customCodePatterns.clear();
    _ignoreKeywords.clear();
  }

  /// 清除仅忽略关键词
  /// 原项目：fun clearIgnoreKeywords()
  void clearIgnoreKeywords() {
    _ignoreKeywords.clear();
  }

  // ========================
  // 核心解析方法（对应原项目第28-98行 parseSms）
  // ========================

  /// 解析一条短信，返回 ParseResult
  ///
  /// 流程：
  /// 1. 检查忽略关键词 → 命中则返回失败
  /// 2. 尝试自定义地址模式（子串包含）
  /// 3. 尝试自定义码模式（正则，捕获组1）
  /// 4. 如果自定义没找到地址 → 用内置正则提取（优先快递柜，其次通用地址）
  /// 5. 始终提取柜号数字
  /// 6. 如果自定义没提取到码 → 用内置 codePattern 提取（取最后一个匹配）
  /// 7. 清理地址标点和"取件"子串
  /// 8. 地址和码都非空才算成功
  ParseResult parseSms(String sms) {
    String foundAddress = '';
    String foundCode = '';

    // ---- Step 1: 忽略关键词检查（原项目第32-37行）----
    for (final keyword in _ignoreKeywords) {
      if (keyword.trim().isNotEmpty &&
          sms.toLowerCase().contains(keyword.toLowerCase())) {
        return ParseResult(address: '', code: '', lockerNumber: '', success: false);
      }
    }

    // ---- Step 2: 自定义地址模式 - 子串包含匹配（原项目第39-45行）----
    for (final pattern in _customAddressPatterns) {
      if (sms.toLowerCase().contains(pattern.toLowerCase())) {
        foundAddress = pattern;
        break;
      }
    }

    // ---- Step 3: 自定义码模式 - 正则匹配，取捕获组1（原项目第46-52行）----
    for (final pattern in _customCodePatterns) {
      final match = pattern.firstMatch(sms);
      if (match != null) {
        foundCode = match.group(1)?.toString() ?? '';
        break;
      }
    }

    // ---- Step 4: 内置地址提取（原项目第54-72行，仅当自定义未找到时）----
    if (foundAddress.isEmpty) {
      // 4a. 优先匹配快递柜地址
      if (preferLockerAddress) {
        final lockerMatch = _lockerPattern.firstMatch(sms);
        foundAddress = lockerMatch?.group(0) ?? '';
      }

      // 4b. 快递柜没匹配到，使用通用地址正则
      if (foundAddress.isEmpty) {
        final addressMatcher = _addressPattern.allMatches(sms);
        String longestAddress = '';
        for (final match in addressMatcher) {
          final currentAddress = match.group(2)?.toString() ?? '';
          if (currentAddress.length > longestAddress.length) {
            longestAddress = currentAddress;
          }
        }
        foundAddress = longestAddress;
      }
    }

    // ---- Step 5: 柜号数字提取（原项目第74-76行，始终执行）----
    final lockerMatch = _lockerPattern.firstMatch(sms);
    final lockerNumber = lockerMatch?.group(1) ?? '';

    // ---- Step 6: 内置取件码提取（原项目第78-89行，仅当自定义未提取到时）----
    if (foundCode.isEmpty) {
      // 取最后一个匹配（原项目 while 循环取最后一次）
      Match? lastMatch;
      for (final match in _codePattern.allMatches(sms)) {
        lastMatch = match;
      }

      if (lastMatch != null) {
        final match = lastMatch.group(0);
        // 按分隔符拆分多个取件码（原项目第84行）
        final codes = match?.split(RegExp(r'[，,、]'));
        foundCode = codes?.map((c) => c.trim()).join(', ') ?? '';
        // 移除非法字符（原项目第86行）
        foundCode = foundCode.replaceAll(RegExp(r'[^A-Za-z0-9-, ]'), '');
      }
    }

    // ---- Step 7: 地址清理（原项目第90-91行）----
    foundAddress = foundAddress.replaceAll(RegExp(r'[，,。]'), '');
    foundAddress = foundAddress.replaceAll('取件', '');

    // ---- Step 8: 返回结果（原项目第92-97行）----
    return ParseResult(
      address: foundAddress,
      code: foundCode,
      lockerNumber: lockerNumber,
      success: foundAddress.isNotEmpty && foundCode.isNotEmpty,
    );
  }
}
```

---

## 3. 从 SharedPreferences 加载自定义规则到 Parser

对应原项目 `save_data.kt` 中的 `loadCustomRulesToParser()` 函数。

```dart
import 'package:shared_preferences/shared_preferences.dart';

/// 将持久化的自定义规则加载到 SmsParser 中
/// 对应原项目 save_data.kt 第14-19行 loadCustomRulesToParser()
Future<void> loadCustomRulesToParser(SmsParser parser) async {
  final prefs = await SharedPreferences.getInstance();

  // 加载自定义地址模式
  final addressPatterns = prefs.getStringList('address') ?? [];
  for (final p in addressPatterns) {
    if (p.trim().isNotEmpty) parser.addCustomAddressPattern(p);
  }

  // 加载自定义码模式
  final codePatterns = prefs.getStringList('code') ?? [];
  for (final p in codePatterns) {
    if (p.trim().isNotEmpty) parser.addCustomCodePattern(p);
  }

  // 加载忽略关键词
  final ignoreKeywords = prefs.getStringList('ignoreKeywords') ?? [];
  for (final k in ignoreKeywords) {
    if (k.trim().isNotEmpty) parser.addIgnoreKeyword(k);
  }

  // 加载"优先匹配快递柜"设置
  parser.preferLockerAddress = prefs.getBool('prefer_locker_address') ?? true;
}
```

---

## 4. 自定义规则的生成（用户添加规则时）

对应原项目 `AddRuleScreen.kt` 第168-185行。当用户从一条解析失败的短信中手动选中取件码文本后，系统自动生成正则规则。

```dart
/// 根据用户选中的码文本，自动生成正则规则字符串
///
/// 原始短信: "【XX快递】包裹已到菜鸟驿站，取件码为 QR1234，请尽快取件"
/// 用户选中: "QR1234"
/// 生成正则: \Q【XX快递】包裹已到菜鸟驿站，取件码为 \E([\s\S]{2,})\Q，请尽快取件\E
///
/// 对应原项目 AddRuleScreen.kt 第168-185行
String generateCodeRule(String smsBody, String userSelectedCode) {
  // 用用户选中的码文本将短信分割为前后两部分
  final parts = smsBody.split(userSelectedCode);

  if (parts.length == 2) {
    // 正常情况：能分割成前后两段
    // 前半段转义 + 捕获组 + 后半段转义
    return RegExp.escape(parts[0]) + r'([\s\S]{2,})' + RegExp.escape(parts[1]);
  } else {
    // 兜底：分割失败时，把整个短信转义，再把码文本替换为捕获组
    return RegExp.escape(smsBody).replaceFirst(
      RegExp.escape(userSelectedCode),
      r'([\s\S]{2,})',
    );
  }
}
```

**使用方式**：

```dart
// 用户在 UI 中选中了码文本 "QR1234"
final rule = generateCodeRule(smsBody, "QR1234");

// 保存到 SharedPreferences
final prefs = await SharedPreferences.getInstance();
final codePatterns = prefs.getStringList('code')?.toSet() ?? {};
codePatterns.add(rule);
await prefs.setStringList('code', codePatterns.toList());

// 加载到 parser
parser.addCustomCodePattern(rule);
```

---

## 5. 忽略关键词的保存与读取

```dart
/// 添加忽略关键词到持久化存储
Future<void> addIgnoreKeyword(String keyword) async {
  final prefs = await SharedPreferences.getInstance();
  final set = prefs.getStringList('ignoreKeywords')?.toSet() ?? {};
  set.add(keyword);
  await prefs.setStringList('ignoreKeywords', set.toList());
}

/// 移除忽略关键词
Future<void> removeIgnoreKeyword(String keyword) async {
  final prefs = await SharedPreferences.getInstance();
  final set = prefs.getStringList('ignoreKeywords')?.toSet() ?? {};
  set.remove(keyword);
  await prefs.setStringList('ignoreKeywords', set.toList());
}

/// 读取所有忽略关键词
Future<Set<String>> getIgnoreKeywords() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getStringList('ignoreKeywords')?.toSet() ?? {};
}
```

---

## 6. 验证自定义规则是否生效

对应原项目 `save_data.kt` 中的 `hasCustomSameDayCode()` 函数。

```dart
/// 检查自定义规则是否能解析给定内容
/// 返回 true 表示规则生效，解析出了地址和码
bool testRuleWithContent(SmsParser parser, String content) {
  final result = parser.parseSms(content);
  return result.success;
}
```

---

## 7. 调用示例（完整初始化 + 解析流程）

```dart
Future<void> example() async {
  // 1. 创建 parser 并加载所有自定义规则
  final parser = SmsParser();
  await loadCustomRulesToParser(parser);

  // 2. 解析单条短信
  final result = parser.parseSms(
    '您的快递已到达菜鸟驿站3号柜，取件码为1234，请尽快取件',
  );

  print(result.success);       // true
  print(result.address);       // 3号柜
  print(result.code);          // 1234
  print(result.lockerNumber);  // 3

  // 3. 测试忽略关键词
  parser.addIgnoreKeyword('广告');
  final r2 = parser.parseSms('【广告】取件码1234已到3号柜');
  print(r2.success);  // false（被"广告"关键词拦截）

  // 4. 用户手动添加规则
  const sms = '【XX快递】包裹已到，提货号 AB-5678 请凭码取件';
  const userCode = 'AB-5678';
  final rule = generateCodeRule(sms, userCode);
  parser.addCustomCodePattern(rule);
  parser.addCustomAddressPattern('XX快递');

  final r3 = parser.parseSms(sms);
  print(r3.success);    // true
  print(r3.address);    // XX快递
  print(r3.code);       // AB-5678
}
```
