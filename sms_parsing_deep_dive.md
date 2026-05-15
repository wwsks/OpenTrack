# 短信识别规则深度解析 — 实现指导

> 本文档详细拆解取件码短信识别的完整实现逻辑，包括正则表达式设计、解析算法流程、自定义规则机制，以及 Dart 语言的等价实现。供另一个 agent 参考实现。

---

## 一、解析引擎整体设计

短信解析的核心是一个**多层降级匹配**的流水线：

```
短信原文
  │
  ├─ 1. 忽略关键词检查 ──→ 命中则直接跳过，不解析
  │
  ├─ 2. 自定义规则（用户手动添加的）
  │     ├─ 自定义地址模式（子串包含匹配）
  │     └─ 自定义码模式（正则匹配，捕获组1=取件码）
  │
  ├─ 3. 内置地址提取（仅当自定义规则未命中时）
  │     ├─ 优先：快递柜地址（"N号柜"格式）
  │     └─ 降级：通用地址（地址关键词 + 后续内容）
  │
  ├─ 4. 柜号数字提取（始终执行，独立于地址提取）
  │
  └─ 5. 内置取件码提取（仅当自定义规则未提取到码时）
        └─ 正则匹配关键词 + 后续字母数字
```

**成功条件**：地址和取件码都非空才算解析成功。

---

## 二、三条核心正则详解

### 2.1 柜号正则 `lockerPattern`

**用途**：从短信中提取快递柜的柜号（如"3号柜"中的"3"）。

**正则**（原始字符串）：
```
(?i)([0-9]+)号(?:柜|快递柜|丰巢柜|蜂巢柜|熊猫柜|兔喜快递柜)
```

**Dart 等价**：
```dart
final lockerPattern = RegExp(
  r'([0-9]+)号(?:柜|快递柜|丰巢柜|蜂巢柜|熊猫柜|兔喜快递柜)',
  caseSensitive: false,
);
```

**逐段拆解**：

| 片段 | 含义 |
|------|------|
| `(?i)` | 不区分大小写（Dart 中用 `caseSensitive: false` 替代） |
| `([0-9]+)` | **捕获组1**：一个或多个数字，这就是柜号 |
| `号` | 字面量"号" |
| `(?:柜\|快递柜\|丰巢柜\|蜂巢柜\|熊猫柜\|兔喜快递柜)` | 非捕获组，匹配"柜"的类型变体 |

**匹配示例**：

| 输入 | 匹配结果 | 捕获组1（柜号） |
|------|----------|----------------|
| `3号柜取件码1234` | `3号柜` | `3` |
| `15号丰巢柜` | `15号丰巢柜` | `15` |
| `已放入2号熊猫柜` | `2号熊猫柜` | `2` |
| `兔喜快递柜5号` | 不匹配（"号"必须在"柜"前面） | — |

**注意**：这个正则要求**数字在前、"号"在中间、柜类型在后**。如果短信格式是"柜5号"，不会匹配。

---

### 2.2 地址正则 `addressPattern`

**用途**：从短信中提取收货地址或存放位置。

**正则**：
```
(?i)(地址|收货地址|送货地址|位于|放至|已到达|到达|已到|送达|到|已放入|已存放至|已存放|放入)[\s\S]*?([\w\s-]+?(?:门牌|驿站|快递点|门面|柜|,|，|。|$))
```

**Dart 等价**：
```dart
final addressPattern = RegExp(
  r'(地址|收货地址|送货地址|位于|放至|已到达|到达|已到|送达|到|已放入|已存放至|已存放|放入)'
  r'[\s\S]*?'
  r'([\w\s-]+?(?:门牌|驿站|快递点|门面|柜|,|，|。|$))',
  caseSensitive: false,
);
```

**逐段拆解**：

| 片段 | 含义 |
|------|------|
| `(地址\|收货地址\|送货地址\|位于\|放至\|已到达\|到达\|已到\|送达\|到\|已放入\|已存放至\|已存放\|放入)` | **捕获组1**：地址引导关键词。注意"到"排在"已到达"后面，否则"已到达"会先被"到"截断 |
| `[\s\S]*?` | 非贪婪匹配任意字符（包括换行），尽可能少地消耗字符 |
| `([\w\s-]+?)` | **捕获组2**：实际地址内容。`\w`匹配字母数字下划线，`\s`匹配空白，`-`匹配横杠。非贪婪 |
| `(?:门牌\|驿站\|快递点\|门面\|柜\|,\|，\|。\|$)` | 地址的终止标记：遇到这些词/符号就停止 |

**关键设计点**：

1. **引导关键词的顺序很重要**：`已到达` 必须排在 `到达` 前面，`到达` 必须排在 `到` 前面。因为正则引擎从左到右尝试，如果 `到` 排在 `已到达` 前面，"已到达"中的"到"就会被先匹配，导致后续的"已达"成为地址内容的一部分。

2. **非贪婪 `*?`**：`[\s\S]*?` 尽可能少地消耗字符，是为了快速跳过关键词和地址之间的无关内容（如标点、空格）。

3. **地址终止条件**：遇到"驿站"、"快递点"、"柜"、逗号、句号就停止。这意味着地址会被截取到这些标记之前。

4. **取最长匹配**：代码中遍历所有匹配结果，取捕获组2最长的那个。这是因为一条短信中可能有多处地址关键词（如"地址...已放入..."），最长的那个通常是完整地址。

**匹配示例**：

| 输入 | 捕获组2（地址） |
|------|----------------|
| `已到达北京市朝阳区XX小区菜鸟驿站，取件码1234` | `北京市朝阳区XX小区菜鸟` （在"驿站"处停止） |
| `已放入3号丰巢柜` | `3号丰巢` （在"柜"处停止） |
| `收货地址：上海市浦东新区张江高科` | `上海市浦东新区张江高科` （到末尾停止） |

**已知局限**：地址中如果包含"柜"字会被截断。比如"XX小区3号柜"会被截取为"XX小区3号"之前的部分。这就是为什么需要 `lockerPattern` 作为补充。

---

### 2.3 取件码正则 `codePattern`

**用途**：从短信中提取取件码。这是三条正则中最复杂的一条。

**正则**（原始字符串，为可读性换行）：
```
(?i)
(请用|取件码为|提货号为|取货码为|提货码为
|取件码（|提货号（|取货码（|提货码（
|取件码『|提货号『|取货码『|提货码『
|取件码【|提货号【|取货码【|提货码【
|取件码\(|提货号\(|取货码\(|提货码\(
|取件码\[|提货号\[|取货码\[|提货码\[
|取件码|提货号|取货码|提货码
|凭|快递|京东|天猫|中通|顺丰|韵达|德邦|菜鸟|拼多多|EMS|闪送|美团|饿了么|盒马|叮咚买菜|UU跑腿
|签收码|签收编号|操作码|提货编码|收货编码|签收编码
|取件編號|提貨號碼|運單碼|快遞碼|快件碼|包裹碼|貨品碼
)
\s*[A-Za-z0-9\s-]{2,}(?:[，,、][A-Za-z0-9\s-]{2,})*
```

**Dart 等价**：
```dart
final codePattern = RegExp(
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
```

**逐段拆解**：

| 片段 | 含义 |
|------|------|
| `(请用\|取件码为\|...\|貨品碼)` | **捕获组1**：关键词前缀。包含三大类（见下文分类） |
| `\s*` | 关键词和码之间允许0个或多个空白字符 |
| `[A-Za-z0-9\s-]{2,}` | 取件码本体：2个以上字母、数字、空格或横杠 |
| `(?:[，,、][A-Za-z0-9\s-]{2,})*` | 可选的多个码：用中文逗号、英文逗号或顿号分隔 |

**关键词三大分类**：

| 分类 | 关键词 | 说明 |
|------|--------|------|
| **取件码直接描述** | 取件码、提货号、取货码、提货码、签收码、签收编号、操作码、提货编码、收货编码、签收编码 | 短信中明确写了"取件码XXX"的格式 |
| **带括号变体** | 取件码（、取件码【、取件码(、取件码[、取件码『 | 关键词后面紧跟括号，码在括号内 |
| **快递公司名** | 京东、天猫、中通、顺丰、韵达、德邦、菜鸟、拼多多、EMS、闪送、美团、饿了么、盒马、叮咚买菜、UU跑腿、快递 | 没有"取件码"字样，但公司名后面直接跟码 |
| **其他动作词** | 请用、凭 | 如"请用ABC123取件"、"凭码XYZ取件" |
| **繁体中文** | 取件編號、提貨號碼、運單碼、快遞碼、快件碼、包裹碼、貨品碼 | 港澳台地区使用 |

**取件码的字符范围**：`[A-Za-z0-9\s-]` 包含：
- 大小写英文字母（A-Z, a-z）
- 数字（0-9）
- 空格
- 横杠（-）

这意味着中文字符不会被当作取件码的一部分。

**多码分隔**：`(?:[，,、][A-Za-z0-9\s-]{2,})*` 允许一条短信中有多个取件码，用以下符号分隔：
- `，` 中文全角逗号
- `,` 英文半角逗号
- `、` 中文顿号

**匹配示例**：

| 输入 | 匹配结果 |
|------|----------|
| `取件码为1234，请尽快取件` | `取件码为1234` |
| `取件码：5678，9012` | `取件码：5678，9012`（但冒号不匹配，实际会匹配到后面的"5678，9012"如果前面有其他关键词） |
| `【顺丰】签收码ABC123` | `签收码ABC123` |
| `京东快递JD8888已到达` | `京东快递JD8888`（"京东"是关键词，"快递JD8888"中"快递"也被消耗了——注意这里"快递"也是关键词） |
| `菜鸟：取件码【9999】` | `取件码【9999` （不包含右括号】，因为】不在字符范围内） |

---

## 三、解析算法逐步流程

### 3.1 `parseSms(sms)` 完整流程

```dart
ParseResult parseSms(String sms) {
  String foundAddress = '';
  String foundCode = '';

  // ===== Step 1: 忽略关键词检查 =====
  // 如果短信包含任何用户设置的忽略关键词，直接返回失败
  // 匹配不区分大小写
  for (final keyword in ignoreKeywords) {
    if (keyword.trim().isNotEmpty &&
        sms.toLowerCase().contains(keyword.toLowerCase())) {
      return ParseResult(address: '', code: '', lockerNumber: '', success: false);
    }
  }

  // ===== Step 2: 自定义规则优先 =====
  // 2a. 自定义地址模式：简单的子串包含匹配
  //     用户填入的字符串如果出现在短信中，就作为地址
  for (final pattern in customAddressPatterns) {
    if (sms.toLowerCase().contains(pattern.toLowerCase())) {
      foundAddress = pattern;  // 注意：地址就是用户填入的模式本身
      break;
    }
  }

  // 2b. 自定义码模式：正则匹配，捕获组1 = 取件码
  //     用户添加规则时，系统会自动生成正则（见第五章）
  for (final pattern in customCodePatterns) {
    final match = pattern.firstMatch(sms);
    if (match != null) {
      foundCode = match.group(1) ?? '';  // 取捕获组1
      break;
    }
  }

  // ===== Step 3: 内置地址提取（仅当自定义规则未找到地址时） =====
  if (foundAddress.isEmpty) {
    // 3a. 优先匹配快递柜地址（如果设置开启）
    if (preferLockerAddress) {
      final lockerMatch = lockerPattern.firstMatch(sms);
      if (lockerMatch != null) {
        foundAddress = lockerMatch.group(0) ?? '';  // 整个匹配（如"3号丰巢柜"）
      }
    }

    // 3b. 如果快递柜也没匹配到，使用通用地址正则
    if (foundAddress.isEmpty) {
      String longestAddress = '';
      for (final match in addressPattern.allMatches(sms)) {
        final current = match.group(2) ?? '';  // 捕获组2 = 地址内容
        if (current.length > longestAddress.length) {
          longestAddress = current;
        }
      }
      foundAddress = longestAddress;
    }
  }

  // ===== Step 4: 柜号数字提取（始终执行） =====
  // 无论地址用哪种方式提取，都独立提取柜号数字
  final lockerMatch = lockerPattern.firstMatch(sms);
  final lockerNumber = lockerMatch?.group(1) ?? '';  // 捕获组1 = 纯数字

  // ===== Step 5: 内置取件码提取（仅当自定义规则未提取到码时） =====
  if (foundCode.isEmpty) {
    // 取最后一个匹配（原项目用 while 循环取最后一次）
    Match? lastMatch;
    for (final match in codePattern.allMatches(sms)) {
      lastMatch = match;
    }

    if (lastMatch != null) {
      final rawMatch = lastMatch.group(0) ?? '';

      // 按分隔符拆分多个取件码
      final codes = rawMatch.split(RegExp(r'[，,、]'));
      foundCode = codes.map((c) => c.trim()).join(', ');

      // 移除非法字符（保留字母、数字、逗号、横杠、空格）
      foundCode = foundCode.replaceAll(RegExp(r'[^A-Za-z0-9-, ]'), '');
    }
  }

  // ===== Step 6: 地址清理 =====
  foundAddress = foundAddress.replaceAll(RegExp(r'[，,。]'), '');  // 移除标点
  foundAddress = foundAddress.replaceAll('取件', '');              // 移除"取件"子串

  // ===== Step 7: 返回结果 =====
  return ParseResult(
    address: foundAddress,
    code: foundCode,
    lockerNumber: lockerNumber,
    success: foundAddress.isNotEmpty && foundCode.isNotEmpty,
  );
}
```

### 3.2 为什么取"最后一个"匹配？

原项目中 `codePattern` 的匹配逻辑是：

```kotlin
while (codeMatcher.find()) {
    val match = codeMatcher.group(0)
    // ... 处理 match
}
```

`while` 循环会遍历所有匹配，但每次都会覆盖 `foundCode`，所以最终保留的是**最后一个匹配**。

**设计原因**：短信模板通常把取件码放在短信末尾或后半段。取最后一个匹配可以避免短信开头的无关内容（如公司名称"京东"）被误匹配为取件码前缀。

**Dart 实现**：
```dart
Match? lastMatch;
for (final match in codePattern.allMatches(sms)) {
  lastMatch = match;
}
```

---

## 四、后处理逻辑

### 4.1 取件码后处理

```dart
// 1. 按分隔符拆分
final codes = rawMatch.split(RegExp(r'[，,、]'));
// "取件码1234，5678" → ["取件码1234", "5678"]

// 2. 去空格后重新拼接
foundCode = codes.map((c) => c.trim()).join(', ');
// → "取件码1234, 5678"

// 3. 移除非法字符（保留字母、数字、逗号、横杠、空格）
foundCode = foundCode.replaceAll(RegExp(r'[^A-Za-z0-9-, ]'), '');
// → "1234, 5678"（"取件码"三个中文字被移除）
```

**关键点**：步骤3会移除关键词文字本身（如"取件码"、"签收码"等中文字），只留下字母数字部分。

### 4.2 地址后处理

```dart
// 移除标点
foundAddress = foundAddress.replaceAll(RegExp(r'[，,。]'), '');
// 移除"取件"子串（因为"取件"常出现在地址描述中但不是地址本身）
foundAddress = foundAddress.replaceAll('取件', '');
```

---

## 五、自定义规则的生成机制

### 5.1 用户操作流程

1. 用户看到一条解析失败的短信
2. 进入"新增规则"页面，看到短信原文
3. 从短信中**复制取件码部分**填入输入框
4. 从短信中**复制地址部分**填入输入框
5. 点击"自动添加规则"

### 5.2 码规则的自动生成算法

当用户填入取件码文本后，系统自动生成正则：

```dart
// 原始短信："【XX快递】您的包裹已到达菜鸟驿站，取件码为 QR1234，请尽快取件"
// 用户填入的码文本："QR1234"

// Step 1: 用码文本将短信分割为两部分
final parts = message.split(codePattern, limit = 2);
// parts[0] = "【XX快递】您的包裹已到达菜鸟驿站，取件码为 "
// parts[1] = "，请尽快取件"

// Step 2: 生成正则 = quote(前半段) + 捕获组 + quote(后半段)
final regexPattern = Pattern.quote(parts[0]) + r'([\s\S]{2,})' + Pattern.quote(parts[1]);
// 结果: \Q【XX快递】您的包裹已到达菜鸟驿站，取件码为 \E([\s\S]{2,})\Q，请尽快取件\E
```

**生成的正则含义**：
- `\Q...\E`：Java/Dart 的字面量引用，中间的内容不做正则解析
- `([\s\S]{2,})`：捕获组，匹配2个以上任意字符（这就是取件码）

**这样设计的好处**：下次遇到格式相同的短信（同样的前缀和后缀），就能自动提取中间的取件码部分，即使取件码的格式不在内置正则的覆盖范围内。

### 5.3 Dart 中的等价实现

```dart
String generateCodeRule(String smsBody, String userCodeText) {
  final parts = smsBody.split(userCodeText);
  if (parts.length == 2) {
    // 前半段和后半段都用 RegExp.escape 转义为字面量
    return RegExp.escape(parts[0]) + r'([\s\S]{2,})' + RegExp.escape(parts[1]);
  } else {
    // 分割失败的兜底：整个短信转义，把码文本替换为捕获组
    return RegExp.escape(smsBody).replaceFirst(
      RegExp.escape(userCodeText),
      r'([\s\S]{2,})',
    );
  }
}
```

> **注意**：Dart 没有 `\Q...\E` 语法，但 `RegExp.escape()` 会转义所有正则特殊字符，效果等价。

### 5.4 地址规则

地址规则更简单——直接用用户输入的字符串做子串匹配：

```dart
// 用户填入地址："XX小区菜鸟驿站"
// 匹配逻辑：sms.contains("XX小区菜鸟驿站")
// 如果短信中包含这个子串，就用它作为地址
```

---

## 六、分组、去重与排序

### 6.1 按地址分组

解析成功后，所有 `SmsData` 按 `address` 字段分组到 `ParcelData` 中。

**地址映射**：用户可以给地址设置标签（如把"3号丰巢柜"和"5号丰巢柜"都映射到"丰巢柜"标签）。分组时使用映射后的标签：

```dart
final groupAddress = addressMappings[originalAddress] ?? originalAddress;
```

### 6.2 同日去重

同一个分组内，如果已有**同一天、同地址、同码**的记录，新记录会被丢弃：

```dart
final isDuplicate = existingParcel.smsDataList.any((existing) =>
  existing.address == newItem.address &&
  existing.code == newItem.code &&
  isSameDay(existing.sms.timestamp, newItem.sms.timestamp),
);
```

### 6.3 排序规则

**组内排序**（单个地址下的取件码列表）：
1. 有柜号的排前面，无柜号的排后面
2. 有柜号的按柜号数字升序（3号柜 < 5号柜 < 15号柜）
3. 柜号相同的按取件码字母序

**组间排序**（地址分组列表）：
1. 有未取件的排前面
2. 同状态的按地址字母序

---

## 七、完整 Dart 实现汇总

将以上所有逻辑整合为一个可直接使用的 `SmsParser` 类：

```dart
class SmsParser {
  bool preferLockerAddress = true;

  static final lockerPattern = RegExp(
    r'([0-9]+)号(?:柜|快递柜|丰巢柜|蜂巢柜|熊猫柜|兔喜快递柜)',
    caseSensitive: false,
  );

  static final addressPattern = RegExp(
    r'(地址|收货地址|送货地址|位于|放至|已到达|到达|已到|送达|到|已放入|已存放至|已存放|放入)'
    r'[\s\S]*?'
    r'([\w\s-]+?(?:门牌|驿站|快递点|门面|柜|,|，|。|$))',
    caseSensitive: false,
  );

  static final codePattern = RegExp(
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

  final List<String> customAddressPatterns = [];
  final List<RegExp> customCodePatterns = [];
  final List<String> ignoreKeywords = [];

  void addCustomAddressPattern(String p) => customAddressPatterns.add(p);
  void addCustomCodePattern(String p) => customCodePatterns.add(RegExp(p));
  void addIgnoreKeyword(String k) {
    if (k.trim().isNotEmpty && !ignoreKeywords.contains(k)) ignoreKeywords.add(k);
  }
  void clearAllCustomPatterns() {
    customAddressPatterns.clear();
    customCodePatterns.clear();
    ignoreKeywords.clear();
  }

  ParseResult parseSms(String sms) {
    // ... 完整实现见第二章
  }
}
```

---

## 八、边界情况与已知问题

| 场景 | 行为 | 原因 |
|------|------|------|
| 短信不含任何关键词 | 解析失败 | address 和 code 都为空 |
| 有码无地址 | 解析失败 | success 要求两者都非空 |
| 有地址无码 | 解析失败 | 同上 |
| 一条短信多个取件码 | 全部提取，逗号分隔 | `(?:[，,、]...)` 支持多码 |
| 取件码包含中文 | 中文部分被移除 | `[^A-Za-z0-9-, ]` 过滤 |
| 地址中包含"柜"字 | 地址在"柜"处截断 | addressPattern 的终止条件 |
| "已到达"被"到"先匹配 | 不会发生 | "已到达"排在"到"前面 |
| 用户自定义规则和内置规则冲突 | 自定义规则优先 | Step 2 在 Step 3 之前 |
| 短信全是英文 | 关键词匹配失败 | 关键词都是中文/中英混合 |
| 取件码只有1个字符 | 匹配失败 | `{2,}` 要求至少2个字符 |
