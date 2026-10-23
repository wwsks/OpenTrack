# LLM 增强功能（地址归一化 / 取件清单 / ETA 估算）实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 接入 OpenAI 兼容 LLM（用户自填 API Key），实现短信地址归一化分组、取件清单生成、ETA 送达估算三个增强功能。

**Architecture:** 新增独立 LLM 服务层（`LlmService`）+ 配置层（`llm_provider.dart`），三个功能各自通过 prompt 模板调用同一服务；地址归一化结果本地缓存（一个新驿站只调用一次 LLM）；所有功能在 LLM 不可用时优雅降级为现状行为。

**Tech Stack:** Flutter 3.29.3 / Dart 3.7.2、dio（HTTP）、flutter_riverpod（状态）、SharedPreferences（配置与缓存）、crypto（md5 缓存键）。

**Spec:** [docs/superpowers/specs/2026-10-18-llm-features-design.md](../specs/2026-10-18-llm-features-design.md)

## Global Constraints

- Flutter SDK 调用方式：`C:\dev\flutter\bin\flutter.bat`（不在 PATH；沙箱需禁用才能运行 flutter 命令）。
- 状态管理只用 Riverpod；持久化用 SharedPreferences（LLM 配置/缓存）；页面转场用 `SlideFadeRoute`；主题色从 `AppTheme` 取，不硬编码。
- LLM 默认值：baseUrl `https://api.deepseek.com/v1`，model `deepseek-chat`，enabled `false`。
- 统一 LLM 请求超时 30 秒。发往模型服务的数据仅限：驿站地址文本、未完成取件码+地址、快递公司+轨迹节点文本。绝不发送手机号、快递单号、快递100 API Key。
- 归一化规则（写入 system prompt）：同一物理站点的不同表述归一到信息最全的名称；不同站点绝不合并；拿不准保留原名（宁可不合并，不可误合并）。
- 后台任务（`background_service.dart`）路径不触发 LLM 调用。
- 硅基流动测试 Key 在 `C:\Users\ddc\.opentrack-secrets\llm_api.env`（`SILICONFLOW_API_KEY`），只用于 E2E 测试注入，**绝不写入源码或提交 git**。
- UI 文案见各任务，与 spec 一致。

## Review Focus

以下失败模式最可能咬人，每条已钉到对应任务的测试：

1. **LLM 未配置时现有功能零回归**（归一化跳过=现状分组、入口隐藏）→ Task 4 的 `null normalizer 保持现状分组` 测试 + Task 7 的 widget_test 回归。
2. **归一化失败或 LLM 返回脏 JSON 时不得污染缓存**（写入错误映射会永久错误分组）→ Task 4 的 `失败不写缓存`、`脏 JSON 整批拒绝` 测试。
3. **相似驿站误合并比不合并更糟**（两个不同菜鸟驿站门店被合成一组，用户漏取件）→ Task 4 的 prompt 规则（拿不准保留原名）+ `两个相似地址合并为一组` 与 `normalizer 返回原名时独立分组` 测试。
4. **ETA 缓存键必须随轨迹更新失效**（轨迹变了还显示旧估算会误导）→ Task 6 的 `轨迹文本变化导致缓存失效` 测试。
5. **401 鉴权失败必须在设置页可见**（用户配错 Key 时全静默降级会让人以为功能坏了）→ Task 3 的 `测试连接遇 401 显示 API Key 无效` 测试。

---

### Task 1: LLM 存储层（constants + StorageService）

**Files:**
- Modify: `lib/config/constants.dart`
- Modify: `lib/services/storage_service.dart`
- Test: `test/storage_llm_test.dart`

**Interfaces:**
- Consumes: 现有 `StorageService` 的 SharedPreferences 访问模式（`SharedPreferences.getInstance()`）。
- Produces: 后续任务依赖的存取方法（签名见下）。
  - `Future<bool> getLlmEnabled()` 默认 `false`；`Future<void> setLlmEnabled(bool)` 
  - `Future<String> getLlmBaseUrl()` 默认 `'https://api.deepseek.com/v1'`；`Future<void> setLlmBaseUrl(String)`
  - `Future<String> getLlmModel()` 默认 `'deepseek-chat'`；`Future<void> setLlmModel(String)`
  - `Future<String> getLlmApiKey()` 默认 `''`；`Future<void> setLlmApiKey(String)`
  - `Future<Map<String, String>> getLlmAddressMap()`；`Future<void> setLlmAddressMap(Map<String, String>)`（JSON 字符串存取）
  - `Future<Map<String, Map<String, String>>> getLlmEtaCache()`；`Future<void> setLlmEtaCache(Map<String, Map<String, String>>)`（JSON，条目形如 `{"<hash>": {"estimate": "...", "reason": "..."}}`）

- [ ] **Step 1: 写失败测试** `test/storage_llm_test.dart`

用 `SharedPreferences.setMockInitialValues({})` 验证：
- `getLlmEnabled()` 返回 `false`、`getLlmBaseUrl()` 返回 `'https://api.deepseek.com/v1'`、`getLlmModel()` 返回 `'deepseek-chat'`、`getLlmApiKey()` 返回 `''`（默认值测试）
- `setLlmAddressMap({'长春理工南区菜鸟驿站': '长春理工大学南区菜鸟驿站'})` 后 `getLlmAddressMap()` 原样返回
- `setLlmEtaCache({'h1': {'estimate': '预计10月20日前后送达', 'reason': '干线运输中'}})` 后 `getLlmEtaCache()` 原样返回

注意 `StorageService` 有 `late Box` 字段且本任务不调 `init()`，测试只触碰 SharedPreferences 系方法即可。

- [ ] **Step 2: 运行测试确认失败**

Run: `C:\dev\flutter\bin\flutter.bat test test/storage_llm_test.dart`
Expected: FAIL（方法不存在）

- [ ] **Step 3: 实现**

`constants.dart` 新增 key 常量：`keyLlmEnabled = 'llm_enabled'`、`keyLlmBaseUrl = 'llm_base_url'`、`keyLlmModel = 'llm_model'`、`keyLlmApiKey = 'llm_api_key'`、`keyLlmAddressMap = 'llm_address_map'`、`keyLlmEtaCache = 'llm_eta_cache'`。
`storage_service.dart` 按既有方法模式实现上述 12 个方法，JSON 用 `dart:convert` 的 `json.encode/json.decode`。

- [ ] **Step 4: 运行测试确认通过**

Run: `C:\dev\flutter\bin\flutter.bat test test/storage_llm_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```
git add lib/config/constants.dart lib/services/storage_service.dart test/storage_llm_test.dart
git commit -m "feat: add LLM config and cache storage methods"
```

---

### Task 2: LlmService（OpenAI 兼容调用）

**Files:**
- Create: `lib/services/llm_service.dart`
- Test: `test/llm_service_test.dart`

**Interfaces:**
- Consumes: dio（构造注入便于测试）。
- Produces:
  - `enum LlmErrorType { network, auth, rateLimit, badResponse }`
  - `class LlmException implements Exception`：字段 `final LlmErrorType type; final String message;`
  - `class LlmService`：构造 `LlmService({required String baseUrl, required String model, required String apiKey, Dio? dio})`
    - `Future<String> chat({required String system, required String user, bool jsonMode = false})` — POST `<baseUrl>/chat/completions`，`jsonMode` 为 true 时 `response_format: {"type": "json_object"}`，返回 `choices[0].message.content` 字符串
    - `static Map<String, dynamic>? tryParseJsonObject(String text)` — 从文本提取 JSON 对象：支持 ```json 围栏块，或取首个 `{` 到末个 `}` 的子串；解析失败返回 `null`

- [ ] **Step 1: 写失败测试** `test/llm_service_test.dart`

用自定义 `HttpClientAdapter`（实现 dio 的 `HttpClientAdapter` 接口，返回预设响应）覆盖：
- `chat` 成功：响应 `{"choices":[{"message":{"content":"你好"}}]}` → 返回 `'你好'`，且请求体含 `model: 'deepseek-chat'`、`messages` 两项（system/user）、URL 为 `https://api.deepseek.com/v1/chat/completions`
- `jsonMode` 时请求体含 `response_format`
- 401 → 抛 `LlmException` 且 `type == LlmErrorType.auth`；429 → `rateLimit`；500 → `badResponse`；adapter 抛连接异常 → `network`
- 响应缺 `choices` → `badResponse`
- `tryParseJsonObject`：围栏块 `` ```json\n{"a":1}\n``` `` → `{"a": 1}`；裸 `{"a":1}` → `{"a":1}`；`abc` → `null`；`{"a":}` → `null`

- [ ] **Step 2: 运行测试确认失败**

Run: `C:\dev\flutter\bin\flutter.bat test test/llm_service_test.dart`
Expected: FAIL（类不存在）

- [ ] **Step 3: 实现** `lib/services/llm_service.dart`

`chat` 内部 try/catch：`DioException` 按 `response.statusCode`（401/403→auth，429→rateLimit，其余有响应→badResponse；无响应（连接/超时）→network）分类抛 `LlmException`。`_dio.options.receiveTimeout/sendTimeout/connectTimeout` 均 30s。注意 baseUrl 可能带尾部 `/`，拼 URL 时去重斜杠。

- [ ] **Step 4: 运行测试确认通过**

Run: `C:\dev\flutter\bin\flutter.bat test test/llm_service_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```
git add lib/services/llm_service.dart test/llm_service_test.dart
git commit -m "feat: add OpenAI-compatible LlmService with error classification"
```

---

### Task 3: LLM 配置 Provider + 设置页

**Files:**
- Create: `lib/providers/llm_provider.dart`
- Create: `lib/screens/mine/llm_settings_screen.dart`
- Modify: `lib/screens/mine/mine_screen.dart`（`_buildSettingsCard` 的 ListTile 列表中加「大模型」入口）
- Test: `test/llm_provider_test.dart`

**Interfaces:**
- Consumes: Task 1 的 StorageService 方法、Task 2 的 `LlmService`/`LlmException`。
- Produces:
  - `class LlmSettings`：字段 `final bool enabled; final String baseUrl; final String model; final String apiKey;`，getter `bool get isConfigured => enabled && apiKey.isNotEmpty;`
  - `final llmSettingsProvider = StateNotifierProvider<LlmSettingsNotifier, LlmSettings>`
  - `class LlmSettingsNotifier extends StateNotifier<LlmSettings>`：`Future<void> setEnabled(bool)`、`setBaseUrl(String)`、`setModel(String)`、`setApiKey(String)`
  - `final llmServiceProvider = Provider<LlmService?>((ref))` — `isConfigured` 为 true 时按当前配置构造 `LlmService`，否则 `null`（注意用 `ref.watch(llmSettingsProvider)` 保持同步）
  - `LlmSettings` 默认态：`enabled=false, baseUrl='https://api.deepseek.com/v1', model='deepseek-chat', apiKey=''`

- [ ] **Step 1: 写失败测试** `test/llm_provider_test.dart`

用 `ProviderContainer` + `storageServiceProvider.overrideWithValue(...)`（fake StorageService 用 `SharedPreferences.setMockInitialValues`）：
- 初始 `llmSettingsProvider` 状态为默认值，`isConfigured == false`
- `setApiKey('k')` + `setEnabled(true)` 后 `isConfigured == true`，且持久化后新建 container 读到同样值
- `llmServiceProvider` 在 `isConfigured == false` 时为 `null`，配置齐全后为 `LlmService` 实例
- `测试连接遇 401 显示 API Key 无效`：设置页「测试连接」的错误映射逻辑（`LlmException` → 文案）遇 `LlmErrorType.auth` 返回文案「API Key 无效，请检查后重试」。把该映射写成可测的纯函数 `String llmErrorText(LlmException e)`（放 `llm_provider.dart`），其余类型返回「连接失败，请稍后重试」（`rateLimit` 返回「请求过于频繁，请稍后重试」）

- [ ] **Step 2: 运行测试确认失败**

Run: `C:\dev\flutter\bin\flutter.bat test test/llm_provider_test.dart`
Expected: FAIL

- [ ] **Step 3: 实现**

`llm_provider.dart` 按 `settings_provider.dart` 的 StateNotifier 模式实现。`llm_settings_screen.dart` 用 `SlideFadeRoute` 打开，包含：启用 Switch、服务地址/模型名/API Key 三个 `TextField`（API Key 用 `obscureText`）、「测试连接」按钮（调 `LlmService.chat(system:'ping', user:'ping')`，成功提示「连接成功」，失败用 `llmErrorText`）；页脚隐私说明文案：「地址、取件码与物流轨迹等数据将发送至你配置的模型服务，请谨慎选择服务提供方。」`mine_screen.dart` 在高级设置 ListTile 附近加「大模型」ListTile（图标 `Icons.smart_toy_outlined`）。

- [ ] **Step 4: 运行测试 + 静态分析确认通过**

Run: `C:\dev\flutter\bin\flutter.bat test test/llm_provider_test.dart && C:\dev\flutter\bin\flutter.bat analyze`
Expected: 测试 PASS，analyze 无新问题

- [ ] **Step 5: Commit**

```
git add lib/providers/llm_provider.dart lib/screens/mine/llm_settings_screen.dart lib/screens/mine/mine_screen.dart test/llm_provider_test.dart
git commit -m "feat: add LLM settings provider and settings screen"
```

---

### Task 4: 地址归一化（AddressNormalizer + SmsProcessor 接入）

**Files:**
- Create: `lib/utils/llm_prompts.dart`
- Create: `lib/utils/address_normalizer.dart`
- Modify: `lib/utils/sms_processor.dart`
- Test: `test/address_normalizer_test.dart`、`test/sms_processor_test.dart`

**Interfaces:**
- Consumes: Task 2 `LlmService.chat/tryParseJsonObject`、Task 1 的 `getLlmAddressMap/setLlmAddressMap`。
- Produces:
  - `lib/utils/llm_prompts.dart`：
    - `const String kNormalizeSystemPrompt` — 规则三条：同一站点不同表述归一到信息最全的名称（优先含菜鸟驿站/妈妈驿站/快递超市/丰巢/服务站等通名的完整写法）；不同站点绝不合并；拿不准保留原名。要求只输出 JSON：`{"原地址":"标准名"}`，键必须覆盖输入的每个地址。
    - `String buildNormalizePrompt(List<String> addresses)` — 逐行输出地址
  - `abstract class AddressNormalizer`：`Future<Map<String, String>> normalizeAll(List<String> addresses)`（返回的映射须覆盖全部输入地址；未命中的原样映射）
  - `class LlmAddressNormalizer implements AddressNormalizer`：构造 `LlmAddressNormalizer({required LlmService llm, required StorageService storage})`；逻辑：查缓存全命中→直接返回；有未命中→对未命中地址调 `chat(jsonMode: true)` + `tryParseJsonObject` → 结果与缓存合并写入 `setLlmAddressMap` → 返回；**调用失败或解析失败→不写缓存，未命中的原样返回**。注意 LLM 返回的映射只合并"键在输入集合中且值非空字符串"的条目。
  - `sms_processor.dart`：`process` 与 `loadAndProcess` 均改为 `async` 并增加可选参数 `AddressNormalizer? normalizer`；分组时用 `mapping[address] ?? address` 作 `ParcelData.address`（分组 key 与标题），`SmsData.address` 保持原始地址不变

- [ ] **Step 1: 写失败测试**

`test/address_normalizer_test.dart`（fake `LlmService` 不好做——它不是接口，用真实 `LlmService` 注入 mock `HttpClientAdapter`，或让 `LlmAddressNormalizer` 构造函数接受 `Future<String?> Function(List<String> addresses)?` 测试钩子；**推荐后者**：构造增加可选参数 `Future<String?> Function(List<String>)? bulkQuery`，默认走 LLM，测试注入假实现）：
- 缓存已有条目时不调用 `bulkQuery`，直接返回
- 未命中地址批量调用一次 `bulkQuery`，返回映射与缓存合并后写入 storage
- `bulkQuery` 抛异常 → 返回值中未命中的原样映射，且 `setLlmAddressMap` 不被调用
- `bulkQuery` 返回脏 JSON（`tryParseJsonObject` 为 null）→ 同上不写缓存
- LLM 返回含无关键（输入之外的地址）→ 无关键不进缓存

`test/sms_processor_test.dart`：
- `两个相似地址合并为一组`：构造两条 `SmsModel`（地址 A「长春理工南区菜鸟驿站」、B「长春理工大学南区菜鸟驿站」），fake normalizer 映射到同一标准名 → `result.parcels.length == 1`，`parcels.first.address == 标准名`，`smsDataList.length == 2`
- `normalizer 返回原名时独立分组`：fake 映射为原名 → `result.parcels.length == 2`
- `null normalizer 保持现状分组`：不传 normalizer → `result.parcels.length == 2`，地址为原文

- [ ] **Step 2: 运行测试确认失败**

Run: `C:\dev\flutter\bin\flutter.bat test test/address_normalizer_test.dart test/sms_processor_test.dart`
Expected: FAIL

- [ ] **Step 3: 实现**

按 Interfaces 实现三个文件。`SmsModel` 构造看 `lib/models/sms_model.dart` 现有字段。`process` 中归一化只对 `result.success` 的地址做，`failed` 列表逻辑不变。现有调用方（`pickup_screen._loadData`、`background_service`）随 async 签名调整：`background_service` **不传 normalizer**（保持后台不调 LLM）。

- [ ] **Step 4: 运行测试确认通过**

Run: `C:\dev\flutter\bin\flutter.bat test`
Expected: 全部 PASS（含既有 sms_parser_test）

- [ ] **Step 5: Commit**

```
git add lib/utils/llm_prompts.dart lib/utils/address_normalizer.dart lib/utils/sms_processor.dart test/address_normalizer_test.dart test/sms_processor_test.dart
git commit -m "feat: LLM address normalization with local cache, merged station grouping"
```

---

### Task 5: 取件清单生成

**Files:**
- Modify: `lib/utils/llm_prompts.dart`
- Modify: `lib/screens/pickup/pickup_screen.dart`（`_PickupScreenState` 改为 `ConsumerState<PickupScreen>`，AppBar actions 加按钮与底部弹层）
- Test: `test/llm_prompts_test.dart`

**Interfaces:**
- Consumes: Task 2 `LlmService.chat`、Task 3 `llmServiceProvider`/`llmSettingsProvider`。
- Produces:
  - `String buildPickupListPrompt(List<SmsData> items)` — 每项输出「驿站：{address}｜取件码：{code}｜柜号：{lockerNumber}」（lockerNumber 为空则省略）；`const String kPickupListSystemPrompt` — 生成到驿站一次性取完的简短清单：按驿站分组、站内按柜号升序排列取件码、末尾附总计（N 个驿站 M 件）；纯文本输出，不加解释
  - UI 行为：AppBar 新增 `IconButton(icon: Icons.checklist, tooltip: '生成取件清单')`，仅当 `llmSettingsProvider.isConfigured` 时显示；点击弹出 `showModalBottomSheet`：标题「取件清单」，loading → `chat` 成功显示清单文本 + 「复制」按钮（`Clipboard.setData`，复制后 `SnackBar`「已复制」）；失败显示「生成失败，点击重试」（点击重新发起）；底部小字「由 AI 生成，取件前请核对」

- [ ] **Step 1: 写失败测试** `test/llm_prompts_test.dart`

- `buildPickupListPrompt` 包含每项的地址与取件码，柜号为空的行不含「柜号」字样
- `kPickupListSystemPrompt` 含「按驿站分组」「柜号升序」「总计」关键词（防 prompt 回归）

- [ ] **Step 2: 运行测试确认失败**

Run: `C:\dev\flutter\bin\flutter.bat test test/llm_prompts_test.dart`
Expected: FAIL

- [ ] **Step 3: 实现**

按 Interfaces 实现。取清单输入：当前 `_parcels` 中所有 `!isCompleted` 的 `SmsData`（跨驿站汇总）。`SmsData.code` 可能含多码（`'a, b'`），直接透传给 prompt。

- [ ] **Step 4: 运行测试 + 分析确认通过**

Run: `C:\dev\flutter\bin\flutter.bat test test/llm_prompts_test.dart && C:\dev\flutter\bin\flutter.bat analyze`
Expected: PASS、无新问题

- [ ] **Step 5: Commit**

```
git add lib/utils/llm_prompts.dart lib/screens/pickup/pickup_screen.dart test/llm_prompts_test.dart
git commit -m "feat: AI pickup list generation on pickup screen"
```

---

### Task 6: ETA 送达估算

**Files:**
- Modify: `lib/utils/llm_prompts.dart`
- Modify: `lib/screens/detail/detail_screen.dart`（`_TimelineCard` 之后加 `_EtaCard`）
- Test: `test/llm_prompts_test.dart`（追加用例）

**Interfaces:**
- Consumes: Task 2 `LlmService`、Task 3 `llmServiceProvider`、Task 1 的 `getLlmEtaCache/setLlmEtaCache`、`crypto` 包的 `md5`。
- Produces:
  - `String buildEtaPrompt({required String companyName, required String traceContext, required String traceTime})`；`const String kEtaSystemPrompt` — 根据当前物流环节与城市间常规时效给出估算，只输出 JSON `{"estimate":"预计X月X日前后送达","reason":"一句话依据"}`；拿不准就给区间并降低语气
  - `class EtaEstimate { final String estimate; final String reason; }` 与 `EtaEstimate? tryParseEta(String text)`（用 `LlmService.tryParseJsonObject` 提取后取 `estimate`/`reason` 字段，缺字段返回 null）
  - `String etaCacheKey(String traceContext, String traceTime)` → `md5('$traceContext|$traceTime').toString()`（放 `llm_prompts.dart`）
  - UI 行为：`_EtaCard` 仅在 `_trackingInfo != null && !isSigned && llmSettingsProvider.isConfigured` 时显示；标题「预计送达（估算）」，主文本 `estimate`，灰色小字 `reason`，角注「AI 估算，仅供参考」；缓存键用 `info.data.first`（最新轨迹）的 `context+time`；缓存命中直接显示；失败显示「生成失败，点击重试」点击重试；已签收包裹不显示

- [ ] **Step 1: 追加失败测试** `test/llm_prompts_test.dart`

- `tryParseEta`：`{"estimate":"预计10月20日前后送达","reason":"干线运输中"}` → 对应字段；缺 `estimate` → `null`；非 JSON 文本 → `null`
- `轨迹文本变化导致缓存失效`：`etaCacheKey('已到达长春转运中心', '2026-10-18 10:00')` != `etaCacheKey('已到达长春转运中心', '2026-10-18 12:00')`，同输入则相等

- [ ] **Step 2: 运行测试确认失败**

Run: `C:\dev\flutter\bin\flutter.bat test test/llm_prompts_test.dart`
Expected: FAIL（新用例失败）

- [ ] **Step 3: 实现**

按 Interfaces 实现。`_EtaCard` 用 `FutureBuilder` 或 StatefulWidget 自持加载态均可，注意详情页刷新轨迹后重新走缓存判断。

- [ ] **Step 4: 运行测试 + 分析确认通过**

Run: `C:\dev\flutter\bin\flutter.bat test && C:\dev\flutter\bin\flutter.bat analyze`
Expected: 全部 PASS、无新问题

- [ ] **Step 5: Commit**

```
git add lib/utils/llm_prompts.dart lib/screens/detail/detail_screen.dart test/llm_prompts_test.dart
git commit -m "feat: AI ETA estimate card on detail screen with trace-keyed cache"
```

---

### Task 7: 回归修复 + 真实 API E2E + 版本号

**Files:**
- Modify: `test/widget_test.dart`
- Create: `test/llm_e2e_test.dart`
- Modify: `pubspec.yaml`、`lib/services/update_service.dart`、`lib/screens/mine/mine_screen.dart`（版本号三处）

**Interfaces:**
- Consumes: 之前全部任务。
- Produces: 可发布状态（0.4.0）。

- [ ] **Step 1: 修复 widget_test**

现状两个错：缺 `ProviderScope`；`find.text('OpenTrack')` 在整个 app 中不存在（只有 MaterialApp title）。改为：`ProviderScope(overrides: [storageServiceProvider.overrideWithValue(fakeStorage)], child: const OpenTrackApp())`，断言 `find.byType(MainScreen)`。fakeStorage 用 `extends StorageService` + `SharedPreferences.setMockInitialValues({})` 并 override 被触碰的方法（`getAllPackages` 返回 `[]`、`getAutoClean` 返回 `false` 等；Hive 系方法不调用）。

- [ ] **Step 2: 运行 widget_test 确认通过**

Run: `C:\dev\flutter\bin\flutter.bat test test/widget_test.dart`
Expected: PASS

- [ ] **Step 3: 写 E2E 测试** `test/llm_e2e_test.dart`

读环境变量 `SILICONFLOW_API_KEY`，为空则 `skip` 整组。配置 `baseUrl: 'https://api.siliconflow.cn/v1'`、模型用 `deepseek-ai/DeepSeek-V3`（硅基流动控制台可见的模型名，若调用 404 换控制台在售模型）。三个用例：
- 归一化：`normalizeAll(['长春理工南区菜鸟驿站','长春理工大学南区菜鸟驿站','重庆市渝北区龙兴菜鸟驿站'])` → 前两者映射同一名、第三者不同名（防误合并）
- 取件清单：两个驿站各 2 个取件码 → 返回非空文本且含两个驿站名
- ETA：给一段运输中轨迹 → `tryParseEta` 解析出非空 estimate

运行方式（Key 注入，不落盘到项目）：
```powershell
$env:SILICONFLOW_API_KEY = (Get-Content C:\Users\ddc\.opentrack-secrets\llm_api.env) -replace '^SILICONFLOW_API_KEY=',''
C:\dev\flutter\bin\flutter.bat test test/llm_e2e_test.dart
```

- [ ] **Step 4: 运行 E2E 确认通过**

Run: 上一步命令
Expected: 3 个用例 PASS（真实网络调用）。若失败按报错修 prompt/解析后重跑。

- [ ] **Step 5: 全量回归**

Run: `C:\dev\flutter\bin\flutter.bat analyze && C:\dev\flutter\bin\flutter.bat test`
Expected: analyze 无问题，全部测试 PASS

- [ ] **Step 6: 版本号三处同步升到 0.4.0**

`pubspec.yaml` 的 `version: 0.4.0+1`；`lib/services/update_service.dart` 的 `_currentVersion = '0.4.0'`；`lib/screens/mine/mine_screen.dart` 的 `'v0.4.0'`。

- [ ] **Step 7: Commit**

```
git add test/widget_test.dart test/llm_e2e_test.dart pubspec.yaml lib/services/update_service.dart lib/screens/mine/mine_screen.dart
git commit -m "test: fix widget test, add LLM e2e tests; bump version to 0.4.0"
```
