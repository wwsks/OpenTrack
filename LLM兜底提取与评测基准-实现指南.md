# 实现指南：失败短信 LLM 兜底提取 + 评测基准 + 数据脱敏

> 写给接手的 agent：本文讲解一轮完整工作**如何做**——目标、设计决策、分步做法、验证方式和踩过的坑。
> 配套代码可从 git 历史参考：`a72f02c`（脱敏）→ `12b2b8d`（兜底提取）→ `7098193`/`37e6196`/`c6e7485`（评测基准），分支 `feature/llm-features`。
> 项目背景：OpenTrack（自邮取）Flutter 快递应用，正准备参加 AI 开源竞赛（截止 2026-10-30）。

---

## 0. 这轮工作的目标（为什么做）

竞赛评分要点驱动的三项工作：

| 编号 | 工作 | 对应评分诉求 |
|---|---|---|
| ② | 失败短信 LLM 兜底提取 | "AI 承担核心功能而非装饰"（创新性 20 分）——让 LLM 复活正则解析失败的短信，识别率提升可量化 |
| ① | 评测基准（数据集 + 脚本） | "实现完成度与可验证效果"（25 分，同分第一比较项）——产出 before/after 可核验数据 + 可复用开放成果 |
| ④ | 测试数据脱敏 | 参赛红线：材料/公开仓库不得暴露学校名称 |

**核心设计原则（贯穿全程）**：
1. **LLM 是增强层**：坏了就退回现状（降级），绝不阻塞核心功能；
2. **数据最小化**：只发必要字段（地址/取件码/短信内容/轨迹），绝不发手机号、快递单号、API Key；
3. **诚实标注**：评测发现的解析器弱点如实计入指标，不修饰数据；
4. **TDD**：先写失败测试再实现，每步有 RED/GREEN 证据。

---

## 1. 失败短信 LLM 兜底提取（怎么做）

### 1.1 设计（先对齐再动手）

在实现前用一段对话把设计定死（调用策略、降级行为、UI 影响、隐私），拿到确认再写代码。关键决策：

- **入口位置**：`sms_processor.process()` 解析出 `failed` 列表后、归一化分组前。恢复的短信移出 `failed`、构造 `SmsData` 并入成功流，**走同一分组/归一化管线**（不另开旁路）。
- **批量调用**：每批最多 20 条（`maxBatchSize`），批内用序号映射回原短信；某批失败只放弃该批，不影响其他批。
- **防编造**：system prompt 明令"提不出取件码的条目一律省略，严禁编造"；解析端只接受「键在输入序号范围内、code 为非空字符串」的条目。
- **降级**：未配置 / 调用异常 / 脏 JSON → `failed` 原样保留，零打扰。`sms_processor` 与提取器**双层** try/catch。
- **透明度**：`SmsData` 加 `final bool extractedByLlm`（默认 false），供 UI 标注与评测区分；注意 `sms_processor` 里重建 `SmsData` 的地方要透传该字段。
- **隐私同步**：此功能会发送短信正文 → 设置页隐私声明必须补上「短信内容」。

### 1.2 文件与接口

| 文件 | 内容 |
|---|---|
| `lib/utils/sms_fallback_extractor.dart`（新） | `abstract class SmsFallbackExtractor { Future<List<SmsData>> extractFailed(List<SmsModel> failed); }` + `LlmSmsFallbackExtractor`（构造 `{required LlmService llm, Future<String?> Function(List<SmsModel> batch)? bulkQuery}`，bulkQuery 是测试钩子，模式同 `address_normalizer.dart`） |
| `lib/utils/llm_prompts.dart`（追加） | `kFallbackExtractSystemPrompt`（JSON 输出契约 + 严禁编造规则）、`buildFallbackExtractPrompt(List<SmsModel>)`（每条一行「N. 正文」） |
| `lib/utils/sms_processor.dart`（改造） | `process`/`loadAndProcess` 增可选参数 `SmsFallbackExtractor? fallback`；解析循环后加兜底段 |
| `lib/models/sms_data.dart`（改造） | 加 `extractedByLlm` 字段 |
| `lib/screens/pickup/pickup_screen.dart`（接线） | `_loadData` 里 LLM 已配置时构造 `LlmSmsFallbackExtractor` 传入（与归一化同一入口） |

**输出 JSON 契约**（写进 prompt）：`{"<编号>": {"code": "...", "address": "...", "locker": "..."}}`，缺地址回退「未知地址」。

### 1.3 测试（TDD，先 RED 后 GREEN）

- `test/sms_fallback_extractor_test.dart`：按序号提取/`extractedByLlm` 为 true/空 code 跳过/缺地址回退/脏 JSON 返回空/异常返回空/超 20 条分批/无关键忽略（8 例）
- `test/sms_processor_test.dart` 追加：恢复的移出 failed 并入分组、返回空时 failed 原样、异常时主流程不受影响、null 保持现状（4 例）
- 假实现写法：`class _FakeFallback implements SmsFallbackExtractor`，可注入任意行为

---

## 2. 评测基准（怎么做）

### 2.1 数据集设计（这是基准的灵魂）

`benchmark/sms_dataset.jsonl`，每行一个 JSON。**四个要素必须有**：

1. **分类 `category`**：`standard`（主流快递模板）/ `nonstandard-code`（如 `B26` 这类非标准码）/ `hard`（口语化、无签名、冒号变体——兜底提取的目标场景）/ `negative`（营销短信等，**不应提取出任何取件码**）。分类分解让指标可信、叙事清晰。
2. **提取标注 `label`**：`code`/`address`/`locker`/`sender`；`code` 为空串 = 负样本。宽容度用 `address_any`（同一地点多种写法，如带括号后缀全称/简称，命中任一即算对）。
3. **分组真值 `station`**：标准驿站名。同一驿站的不同短信写法共享 station，不同但相似的驿站（如南区/北区菜鸟驿站）**必须**都有样本——这是"防误合并"评测的基础。
4. **脱敏**：全部虚构地名（临江大学/临江广场丰巢…），生成器固定随机种子可复现（`benchmark/generate_dataset.ps1`）。

规模参考：136 条（76 standard + 24 nonstandard-code + 24 hard + 12 negative），覆盖约 10 种短信模板 × 6 个驿站 × 2-3 种地址写法。

### 2.2 评测脚本 `benchmark/eval_runner.dart`

**关键约束：纯 Dart**（只 import `sms_parser`/`llm_prompts`/`sms_fallback_extractor`/models/services，不引 Flutter 插件），这样 `dart run benchmark/eval_runner.dart` 直接可跑、方便开源复用。

指标定义：
- **解析成功率**：正样本中产出非空取件码的比例
- **精确识别率**：取件码**且**地址（含 address_any）全对
- **负样本误提取率**：负样本中被提取出码的比例
- **分组 pairwise P/R/F1**：所有已提取样本两两判断"是否同组"（预测同组 = 提取地址相同，`--llm` 时为归一化后地址；真值同组 = station 相同），另报"产生的组数 vs 真实组数"（> 真实值 = 同站被拆分）
- **兜底恢复率**（`--llm`）：正则失败的正样本被 LLM 正确恢复的比例

三种模式：离线（无 Key）/ `--llm`（读 `SILICONFLOW_API_KEY` 环境变量）/ `--audit`（逐条列出解析错误与误提取，**标注质检必备**）。

### 2.3 审计-修标注循环（重要方法论）

生成数据集后**必须**跑 `--audit` 逐条核对，会暴露三类问题，分别处理：

| 审计发现 | 处理方式 |
|---|---|
| 标注不宽容（解析器输出另一种合理写法，如截掉括号后缀） | 修标注：加 `address_any` |
| 解析器真实盲区（如 `B26` 码格式 0% 命中） | **诚实保留**，归入专门分类，不删样本 |
| 解析器真实缺陷（地址边界越界、「快递100」的 100 被当取件码） | **诚实计分**，写进报告当改进素材 |

原则：修"标注错了"，不修"解析器错了"。基准的可信度来自对弱点的诚实。

### 2.4 before/after 产出（真实 API 实测）

```
$env:SILICONFLOW_API_KEY = (从安全存储读取)
dart run benchmark/eval_runner.dart --llm
```

本轮结果（DeepSeek-V3）：精确识别率 58.1% → 91.9%（兜底 42/42）、分组 F1 59.6% → 95.0%（21 组→13 组，真实 6 组）、仅 4 批 LLM 调用。结果 markdown 存 `benchmark/results/`，README 写基线表。

---

## 3. 数据脱敏（怎么做）

1. **扫描**：全仓 grep 真实校名/地名关键词（如「长春」），圈定范围（测试文件 + 已提交文档；未跟踪草稿、历史副本不入库不处理）。
2. **映射替换**：建映射表（长春理工大学→临江大学、长春理工→临江、长春市→临江市、南研楼→南苑楼…），**长串先替换**避免子串截断；机械批量替换后 grep 复查归零。
3. **断言同步**：测试里的期望值（地址字符串）同步换，跑全量测试确认一致。
4. 注意：设计文档/计划文档若已提交进仓库也要替换（公开仓库同样会暴露）。

---

## 4. 工程坑（这轮实际踩过的）

1. **PowerShell 5.1 编码**：`Set-Content`/Write 工具写 UTF-8 无 BOM，PS5.1 按 GBK 读 .ps1 会把中文搞乱、`keystore.properties` 带 BOM 会让首 key 污染（Gradle NPE）。**写完 .ps1/properties 用 `[System.IO.File]::WriteAllText(path, text, New-Object System.Text.UTF8Encoding($true/`$false))` 校准编码**。
2. **工具 shell 的后台任务不可靠**：长命令（>~2 分钟）会被自动转入后台并静默死掉（日志为空、state 卡 Running）。对策：拆短命令前台跑；Flutter 命令需禁用沙箱；PowerShell 5.1 无 `&&`。
3. **`dart`/`flutter` 不在 PATH**：用 `C:\dev\flutter\bin\flutter.bat` / `dart.bat` 全路径。
4. **TDD 的 RED 是编译失败也算**：新类不存在导致的编译错误就是合法的 RED，截图留证即可。
5. **测试断言与实现同步演进**：给模型/管线加字段（如 `extractedByLlm`）时检查所有重建对象的地方（本项目 `sms_processor` 有两处 `SmsData(...)` 构造）。

---

## 5. 交付与验证清单（照此验收）

- [ ] `flutter analyze` 无问题；`flutter test` 全过（基线 86 过 + 3 skip）
- [ ] 兜底提取：12 个单测/集成测试；LLM 未配置时行为与现状逐字节一致
- [ ] 评测：`dart run benchmark/eval_runner.dart` 离线可跑；`--llm` 产出 before/after 报告；`--audit` 可用；README 含指标定义、基线表、脱敏声明、复用说明
- [ ] 脱敏：全仓（除未跟踪草稿）grep 真实校名零命中
- [ ] 隐私：设置页声明覆盖新增的外发数据（短信内容）；prompt 中无手机号/单号/密钥
- [ ] 分 commit 提交（脱敏 / 功能 / 基准分开），消息说明动机

## 6. 如果你要继续做（后续建议）

- 把基准表格写进竞赛技术报告"测试与可验证效果"章节；演示视频用 `--llm` 对照跑评测脚本作素材
- 可复用开放成果打包：`benchmark/` 目录本身（数据集+脚本+README）就是独立可复用组件，可单独发仓库
- 已知改进点（评测诚实记录）：「快递100」签名误提取、无后缀地址边界越界——修这两个解析器弱点能把 standard 类精确率从 86.8% 再往上抬
