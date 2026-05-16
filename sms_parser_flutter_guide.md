# Flutter 短信解析算法实现指导

> 本文档是取件码短信解析的完整算法指导，面向需要在 Flutter 中实现此功能的 agent。
> 重点讲解**如何从短信中提取驿站/快递柜地址信息**。

---

## 一、解析目标

一条典型的取件码短信长这样：

```
【菜鸟驿站】您的快递已到达XX小区3号丰巢柜，取件码为1234，请尽快取件。
```

我们需要从中提取三个信息：

| 字段 | 示例 | 说明 |
|------|------|------|
| `address` | `3号丰巢柜` | 驿站/快递柜/存放地点 |
| `code` | `1234` | 取件码，可能有多个 |
| `lockerNumber` | `3` | 柜号数字（快递柜场景） |

**成功条件**：address 和 code 都非空才算解析成功。只有其中一个则算失败。

---

## 二、地址提取策略（核心）

地址提取是整个解析中最复杂的部分。系统采用**三级降级策略**：

```
优先级1: 用户自定义地址规则（子串包含匹配）
    ↓ 未命中
优先级2: 快递柜地址（"N号柜"格式）
    ↓ 未命中（且 preferLockerAddress=true）
优先级3: 通用地址正则（地址关键词 + 后续内容）
```

### 2.1 优先级1：用户自定义地址规则

最简单的方式——用户手动输入一个字符串，如果短信中包含这个字符串，就用它作为地址。

```dart
// 用户输入："XX小区菜鸟驿站"
// 短信："您的快递已到达XX小区菜鸟驿站，取件码1234"
// 结果：address = "XX小区菜鸟驿站"
```

**实现**：

```dart
for (final pattern in customAddressPatterns) {
  if (sms.toLowerCase().contains(pattern.toLowerCase())) {
    foundAddress = pattern;  // 地址就是用户输入的模式本身
    break;
  }
}
```

### 2.2 优先级2：快递柜地址提取

快递柜短信有非常固定的格式：**数字 + "号" + 柜类型**。

**正则**：

```dart
final lockerPattern = RegExp(
  r'([0-9]+)号(?:柜|快递柜|丰巢柜|蜂巢柜|熊猫柜|兔喜快递柜)',
  caseSensitive: false,
);
```

**匹配规则**：

```
数字 + "号" + 以下任一后缀：
  - 柜（通用）
  - 快递柜
  - 丰巢柜（丰巢品牌）
  - 蜂巢柜（丰巢的别称）
  - 熊猫柜
  - 兔喜快递柜
```

**匹配示例**：

| 短信片段 | 匹配结果 | 柜号数字 |
|----------|----------|----------|
| `3号柜取件码1234` | `3号柜` | `3` |
| `已放入15号丰巢柜` | `15号丰巢柜` | `15` |
| `2号快递柜已满` | `2号快递柜` | `2` |
| `兔喜快递柜5号` | 不匹配 | — |
| `第3个柜子` | 不匹配 | — |

**注意**：这个正则**要求"号"在数字和柜类型之间**。"柜5号"或"第3柜"这类格式不会匹配。

**实现**：

```dart
if (preferLockerAddress) {
  final lockerMatch = lockerPattern.firstMatch(sms);
  if (lockerMatch != null) {
    foundAddress = lockerMatch.group(0)!;  // 整个匹配作为地址，如"3号丰巢柜"
  }
}
```

### 2.3 优先级3：通用地址正则

当短信中没有快递柜格式时，使用通用地址正则。这是最复杂的一条。

**正则**：

```dart
final addressPattern = RegExp(
  r'(地址|收货地址|送货地址|位于|放至|已到达|到达|已到|送达|到|已放入|已存放至|已存放|放入)'
  r'[\s\S]*?'
  r'([\w\s-]+?(?:门牌|驿站|快递点|门面|柜|,|，|。|$))',
  caseSensitive: false,
);
```

**结构拆解**：这条正则由三部分组成。

```
┌─ 引导词 ─────────────────────────────────────────────┐
│ 地址|收货地址|送货地址|位于|放至|已到达|到达|已到|送达|到│
│ 已放入|已存放至|已存放|放入                              │
└──────────────────────────────────────────────────────┘
         │
         ▼
┌─ 跳过中间内容 ──┐
│ [\s\S]*?        │  非贪婪匹配任意字符（含换行）
└─────────────────┘
         │
         ▼
┌─ 地址本体 ──────────────────────────────────────────┐
│ [\w\s-]+?        │  字母/数字/下划线/空格/横杠（非贪婪）│
│ └─ 终止标记 ──┐   │                                   │
│   门牌|驿站    │   │  遇到这些词就停止                   │
│   快递点|门面  │   │                                   │
│   柜|,|，|。|$ │   │                                   │
└──────────────────────────────────────────────────────┘
```

**引导词说明**：

| 引导词 | 典型短信示例 |
|--------|-------------|
| `收货地址` | `收货地址：北京市朝阳区XX路XX号` |
| `送货地址` | `送货地址上海市浦东新区...` |
| `已到达` | `您的快递已到达XX小区菜鸟驿站` |
| `已放入` | `快递已放入3号丰巢柜` |
| `已存放至` | `包裹已存放至XX便利店` |
| `位于` | `包裹位于XX大学快递中心` |
| `放至` | `快递放至小区东门驿站` |
| `送达` | `快递已送达XX大厦` |
| `到达` | `快递到达XX花园` |
| `已到` | `包裹已到XX公寓` |
| `到` | 最宽泛，匹配任何"到XXX" |
| `已存放` | `快递已存放XX代收点` |
| `放入` | `已放入XX智能柜` |

**引导词顺序很重要**：`已到达` 必须排在 `到达` 前面，`到达` 必须排在 `到` 前面。正则引擎从左到右尝试，如果 `到` 排在最前面，"已到达"中的"到"会被先匹配，导致"已达"成为地址的一部分。

**地址终止标记**：

| 终止标记 | 含义 |
|----------|------|
| `驿站` | 菜鸟驿站、妈妈驿站等 |
| `快递点` | XX快递点 |
| `门面` | XX门面 |
| `柜` | 丰巢柜、快递柜等 |
| `门牌` | 门牌号 |
| `,` `，` `。` | 标点符号 |
| `$` | 字符串末尾 |

**匹配时取最长结果**：一条短信中可能有多处地址关键词（如"地址...已放入..."），系统遍历所有匹配，取捕获组2最长的那个。

```dart
if (foundAddress.isEmpty) {
  String longestAddress = '';
  for (final match in addressPattern.allMatches(sms)) {
    final currentAddress = match.group(2) ?? '';
    if (currentAddress.length > longestAddress.length) {
      longestAddress = currentAddress;
    }
  }
  foundAddress = longestAddress;
}
```

**匹配示例**：

| 短信 | 引导词 | 匹配到的地址 | 终止原因 |
|------|--------|-------------|----------|
| `已到达XX小区菜鸟驿站，取件码1234` | `已到达` | `XX小区菜鸟` | 遇到"驿站"停止 |
| `快递已放入3号丰巢柜` | `已放入` | `3号丰巢` | 遇到"柜"停止 |
| `收货地址：北京市朝阳区XX路` | `收货地址` | `北京市朝阳区XX路` | 到末尾停止 |
| `已存放至XX大学快递点` | `已存放至` | `XX大学快递` | 遇到"快递点"停止 |

### 2.4 地址提取的已知局限

| 场景 | 问题 | 原因 |
|------|------|------|
| 地址中含"柜"字 | 地址在"柜"处被截断 | "柜"是终止标记 |
| 地址中含"驿站" | 地址在"驿站"处被截断 | "驿站"是终止标记 |
| 短信无地址关键词 | 无法提取地址 | addressPattern 需要引导词 |
| 地址在取件码后面 | 可能提取不到 | addressPattern 是前向匹配 |

对于这些局限，用户可以通过**自定义地址规则**来覆盖。

---

## 三、取件码提取策略

### 3.1 优先级1：用户自定义码规则

用户添加规则时，系统会自动生成正则。详见第六章。

```dart
for (final pattern in customCodePatterns) {
  final match = pattern.firstMatch(sms);
  if (match != null) {
    foundCode = match.group(1) ?? '';  // 捕获组1 = 取件码
    break;
  }
}
```

### 3.2 优先级2：内置取件码正则

**正则结构**：

```
(关键词前缀) \s* (取件码本体{2,}) (分隔符+下一个码)*
```

**关键词前缀分为五大类**：

**第一类：直接描述词**

```
取件码为 | 提货号为 | 取货码为 | 提货码为
取件码   | 提货号   | 取货码   | 提货码
签收码   | 签收编号 | 操作码
提货编码 | 收货编码 | 签收编码
```

这些词后面直接跟取件码。"为"字是可选的变体。

**第二类：带括号变体**

```
取件码（ | 提货号（ | 取货码（ | 提货码（
取件码【 | 提货号【 | 取货码【 | 提货码【
取件码(  | 提货号(  | 取货码(  | 提货码(
取件码[  | 提货号[  | 取货码[  | 提货码[
取件码『 | 提货号『 | 取货码『 | 提货码『
```

码在括号内，如 `取件码【1234】`。注意正则只匹配到左括号，右括号不在匹配范围内，后续会被字符过滤移除。

**第三类：快递公司名**

```
京东 | 天猫 | 中通 | 顺丰 | 韵达 | 德邦 | 菜鸟 | 拼多多
EMS | 闪送 | 美团 | 饿了么 | 盒马 | 叮咚买菜 | UU跑腿 | 快递
```

没有"取件码"字样，公司名后面直接跟码。如 `京东快递JD8888`。

**第四类：动作词**

```
请用 | 凭
```

如 `请用ABC123取件`、`凭码XYZ取件`。

**第五类：繁体中文**

```
取件編號 | 提貨號碼 | 運單碼 | 快遞碼 | 快件碼 | 包裹碼 | 貨品碼
```

港澳台地区使用。

**取件码本体的字符范围**：

```
[A-Za-z0-9\s-]{2,}
```

- 英文字母（大小写）
- 数字
- 空格
- 横杠 `-`
- **至少2个字符**

**多码支持**：

```
(?:[，,、][A-Za-z0-9\s-]{2,})*
```

用中文逗号 `，`、英文逗号 `,` 或顿号 `、` 分隔的多个码。

**匹配逻辑**：取短信中**最后一个匹配**（而非第一个）。

```dart
Match? lastMatch;
for (final match in codePattern.allMatches(sms)) {
  lastMatch = match;
}
```

**为什么取最后一个**：短信模板通常把取件码放在后半段或末尾。取最后一个可以避免短信开头的公司名等干扰。

**后处理**：

```dart
if (lastMatch != null) {
  final rawMatch = lastMatch.group(0)!;

  // 1. 按分隔符拆分多个码
  final codes = rawMatch.split(RegExp(r'[，,、]'));
  // "取件码1234，5678" → ["取件码1234", "5678"]

  // 2. 去空格后重新拼接
  foundCode = codes.map((c) => c.trim()).join(', ');
  // → "取件码1234, 5678"

  // 3. 移除非法字符（只保留字母、数字、逗号、横杠、空格）
  foundCode = foundCode.replaceAll(RegExp(r'[^A-Za-z0-9-, ]'), '');
  // → "1234, 5678"（"取件码"三个中文字被移除）
}
```

---

## 四、柜号数字提取

独立于地址提取，**始终执行**。即使地址是通过自定义规则或通用正则提取的，柜号数字也会单独提取。

```dart
final lockerMatch = lockerPattern.firstMatch(sms);
final lockerNumber = lockerMatch?.group(1) ?? '';
```

**用途**：
- 在 UI 中用于排序（有柜号的排前面，按柜号升序）
- 在地址标签中显示柜号信息

---

## 五、地址清理

提取到的地址需要做最后清理：

```dart
// 移除标点
foundAddress = foundAddress.replaceAll(RegExp(r'[，,。]'), '');

// 移除"取件"子串（因为"取件"常出现在地址描述中但不是地址本身）
// 例如："XX小区取件菜鸟驿站" → "XX小区菜鸟驿站"
foundAddress = foundAddress.replaceAll('取件', '');
```

---

## 六、自定义规则生成机制

### 6.1 码规则自动生成

当用户从一条解析失败的短信中选中取件码文本后，系统自动生成正则：

```dart
/// [smsBody] 原始短信全文
/// [userSelectedCode] 用户选中的取件码文本
String generateCodeRule(String smsBody, String userSelectedCode) {
  final parts = smsBody.split(userSelectedCode);

  if (parts.length == 2) {
    // 正常：前半段 + 捕获组 + 后半段
    return RegExp.escape(parts[0]) + r'([\s\S]{2,})' + RegExp.escape(parts[1]);
  } else {
    // 兜底：整个短信转义，码文本位置替换为捕获组
    return RegExp.escape(smsBody).replaceFirst(
      RegExp.escape(userSelectedCode),
      r'([\s\S]{2,})',
    );
  }
}
```

**示例**：

```
原始短信: "【XX快递】包裹已到菜鸟驿站，取件码为 QR1234，请尽快取件"
用户选中: "QR1234"

parts[0] = "【XX快递】包裹已到菜鸟驿站，取件码为 "
parts[1] = "，请尽快取件"

生成正则: \Q【XX快递】包裹已到菜鸟驿站，取件码为 \E([\s\S]{2,})\Q，请尽快取件\E
```

下次遇到格式相同的短信，`([\s\S]{2,})` 就能捕获中间的取件码。

### 6.2 地址规则

地址规则不做正则生成，直接存储用户输入的字符串，用子串包含匹配。

---

## 七、完整解析流程（Dart 实现）

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

class SmsParser {
  bool preferLockerAddress = true;

  // ---------- 内置正则 ----------

  static final _lockerPattern = RegExp(
    r'([0-9]+)号(?:柜|快递柜|丰巢柜|蜂巢柜|熊猫柜|兔喜快递柜)',
    caseSensitive: false,
  );

  static final _addressPattern = RegExp(
    r'(地址|收货地址|送货地址|位于|放至|已到达|到达|已到|送达|到|已放入|已存放至|已存放|放入)'
    r'[\s\S]*?'
    r'([\w\s-]+?(?:门牌|驿站|快递点|门面|柜|,|，|。|$))',
    caseSensitive: false,
  );

  static final _codePattern = RegExp(
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

  // ---------- 自定义规则 ----------

  final List<String> _customAddressPatterns = [];
  final List<RegExp> _customCodePatterns = [];
  final List<String> _ignoreKeywords = [];

  void addCustomAddressPattern(String pattern) {
    _customAddressPatterns.add(pattern);
  }

  void addCustomCodePattern(String pattern) {
    _customCodePatterns.add(RegExp(pattern));
  }

  void addIgnoreKeyword(String keyword) {
    if (keyword.trim().isNotEmpty && !_ignoreKeywords.contains(keyword)) {
      _ignoreKeywords.add(keyword);
    }
  }

  void removeIgnoreKeyword(String keyword) {
    _ignoreKeywords.remove(keyword);
  }

  List<String> getIgnoreKeywords() => List.unmodifiable(_ignoreKeywords);

  void clearAllCustomPatterns() {
    _customAddressPatterns.clear();
    _customCodePatterns.clear();
    _ignoreKeywords.clear();
  }

  void clearIgnoreKeywords() {
    _ignoreKeywords.clear();
  }

  // ---------- 核心解析 ----------

  ParseResult parseSms(String sms) {
    String foundAddress = '';
    String foundCode = '';

    // Step 1: 忽略关键词
    for (final keyword in _ignoreKeywords) {
      if (keyword.trim().isNotEmpty &&
          sms.toLowerCase().contains(keyword.toLowerCase())) {
        return ParseResult(address: '', code: '', lockerNumber: '', success: false);
      }
    }

    // Step 2: 自定义地址规则（子串包含）
    for (final pattern in _customAddressPatterns) {
      if (sms.toLowerCase().contains(pattern.toLowerCase())) {
        foundAddress = pattern;
        break;
      }
    }

    // Step 3: 自定义码规则（正则，捕获组1）
    for (final pattern in _customCodePatterns) {
      final match = pattern.firstMatch(sms);
      if (match != null) {
        foundCode = match.group(1) ?? '';
        break;
      }
    }

    // Step 4: 内置地址提取（自定义未命中时）
    if (foundAddress.isEmpty) {
      // 4a: 快递柜地址（优先）
      if (preferLockerAddress) {
        final lockerMatch = _lockerPattern.firstMatch(sms);
        if (lockerMatch != null) {
          foundAddress = lockerMatch.group(0)!;
        }
      }

      // 4b: 通用地址正则（降级）
      if (foundAddress.isEmpty) {
        String longestAddress = '';
        for (final match in _addressPattern.allMatches(sms)) {
          final current = match.group(2) ?? '';
          if (current.length > longestAddress.length) {
            longestAddress = current;
          }
        }
        foundAddress = longestAddress;
      }
    }

    // Step 5: 柜号数字（始终提取）
    final lockerMatch = _lockerPattern.firstMatch(sms);
    final lockerNumber = lockerMatch?.group(1) ?? '';

    // Step 6: 内置取件码提取（自定义未提取到时，取最后一个匹配）
    if (foundCode.isEmpty) {
      Match? lastMatch;
      for (final match in _codePattern.allMatches(sms)) {
        lastMatch = match;
      }
      if (lastMatch != null) {
        final rawMatch = lastMatch.group(0)!;
        final codes = rawMatch.split(RegExp(r'[，,、]'));
        foundCode = codes.map((c) => c.trim()).join(', ');
        foundCode = foundCode.replaceAll(RegExp(r'[^A-Za-z0-9-, ]'), '');
      }
    }

    // Step 7: 地址清理
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

---

## 八、地址分组与标签映射

解析完成后，所有成功的 `SmsData` 按地址分组为 `ParcelData`。

### 8.1 分组逻辑

```dart
// 原始地址 → 分组地址（可能被标签替换）
final groupAddress = addressMappings[originalAddress] ?? originalAddress;
```

用户可以设置**地址标签**，把多个不同的原始地址归到同一个标签下：

```
原始地址 "3号丰巢柜"  →  标签 "小区丰巢"
原始地址 "5号丰巢柜"  →  标签 "小区丰巢"
```

这样 UI 中会显示一个 "小区丰巢" 分组，下面有两条取件码。

### 8.2 地址标签持久化

```dart
/// 保存地址映射
Future<void> saveAddressMapping(String originalAddress, String tag) async {
  final prefs = await SharedPreferences.getInstance();
  final json = prefs.getString('address_mappings_json') ?? '[]';
  final list = (jsonDecode(json) as List).cast<Map<String, dynamic>>();
  list.removeWhere((m) => m['originalAddress'] == originalAddress);
  list.add({'originalAddress': originalAddress, 'tag': tag});
  await prefs.setString('address_mappings_json', jsonEncode(list));
}

/// 读取地址映射
Future<Map<String, String>> getAddressMappings() async {
  final prefs = await SharedPreferences.getInstance();
  final json = prefs.getString('address_mappings_json') ?? '[]';
  final list = (jsonDecode(json) as List).cast<Map<String, dynamic>>();
  return {for (final m in list) m['originalAddress']: m['tag']};
}
```

### 8.3 同日去重

同一个分组内，**同一天、同地址、同码**的记录只保留一条：

```dart
final isDuplicate = existingParcel.smsDataList.any((existing) =>
  existing.address == newItem.address &&
  existing.code == newItem.code &&
  isSameDay(existing.sms.timestamp, newItem.sms.timestamp),
);
```

### 8.4 排序规则

**组内排序**（单个地址下的取件码）：
1. 有柜号的排前面，无柜号排后面
2. 柜号数字升序（3 < 5 < 15）
3. 柜号相同按码字母序

**组间排序**（地址分组列表）：
1. 有未取件的排前面
2. 同状态按地址字母序

---

## 九、格式化取件码显示

长数字取件码（8位以上）每4位加空格，方便阅读：

```dart
String formatPickupCode(String code) {
  return code.split(',').map((singleCode) {
    final trimmed = singleCode.trim();
    if (trimmed.contains('-')) return trimmed;  // 含横杠的不处理
    final digitsOnly = trimmed.replaceAll(RegExp(r'[^\d]'), '');
    if (digitsOnly.length >= 8) {
      return digitsOnly.replaceAllMapped(RegExp(r'.{4}'), (m) => '${m.group(0)} ').trim();
    }
    return digitsOnly;
  }).join(', ');
}

// formatPickupCode("12345678")    → "1234 5678"
// formatPickupCode("AB-1234")     → "AB-1234"
// formatPickupCode("1234")        → "1234"
// formatPickupCode("1234, 5678")  → "1234, 5678"
```

---

## 十、测试用例

| 短信 | 期望 address | 期望 code | 期望 lockerNumber |
|------|-------------|-----------|-------------------|
| `您的快递已到达菜鸟驿站3号柜，取件码为1234` | `3号柜` | `1234` | `3` |
| `快递已放入5号丰巢柜，取件码5678` | `5号丰巢柜` | `5678` | `5` |
| `【顺丰】签收码ABC123，请凭码取件` | (空→失败) | (有码但无地址→失败) | — |
| `京东快递：包裹已到达XX驿站，提货号JD8888` | `XX` | `JD8888` | — |
| `菜鸟：取件码1111，2222已到XX小区快递点` | `XX小区` | `1111, 2222` | — |
| `【中通】快递已放至3号丰巢柜，取件码【9999】` | `3号丰巢柜` | `9999 】` → 清理后 `9999` | `3` |
| `收货地址：北京市朝阳区XX路，提货号ABC` | `北京市朝阳区XX路` | `ABC` | — |
| `广告：取件码1234` (有忽略词"广告") | — | — | — |
