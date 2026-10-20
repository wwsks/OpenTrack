# 短信解析评测基准（OpenTrack benchmark suite）

对 OpenTrack 短信取件码解析管线的**可复现评测**：脱敏标注数据集 + 一键评测脚本，输出识别率、误提取率与驿站分组质量指标。可独立复用于任何短信取件码提取系统的对比评测。

## 快速开始

```bash
# 离线评测（无需任何 API Key）
dart run benchmark/eval_runner.dart

# 带 LLM 增强评测（兜底提取 + 地址归一化，需要 API Key）
export SILICONFLOW_API_KEY=sk-...        # Windows PowerShell: $env:SILICONFLOW_API_KEY = "..."
dart run benchmark/eval_runner.dart --llm

# 审计模式：逐条列出解析错误/误提取的样本（数据集维护用）
dart run benchmark/eval_runner.dart --audit
```

评测报告以 Markdown 写入 `benchmark/results/`。`--llm` 可用环境变量覆盖服务：`LLM_BASE_URL`（默认 `https://api.siliconflow.cn/v1`）、`LLM_MODEL`（默认 `deepseek-ai/DeepSeek-V3`）、`LLM_API_KEY`。

## 数据集：sms_dataset.jsonl

每行一个 JSON 样本：

```json
{
  "id": "s001",
  "body": "【极兔速递】请凭5-2-4805到临江南区菜鸟驿站取运单尾号1392包裹",
  "station": "临江大学南区菜鸟驿站",
  "category": "standard",
  "label": {
    "code": "5-2-4805",
    "address": "临江南区菜鸟驿站",
    "locker": "",
    "sender": "极兔速递",
    "address_any": ["可接受的其他地址写法"]
  }
}
```

- `station`：标准驿站名（**分组真值**）。同一驿站的多种短信写法共享同一 station，用于度量"同站被拆组/异站被误合"。
- `label.code`：期望提取的取件码；**为空串 = 负样本**（营销/通知类短信，不应提取出任何取件码）。
- `label.address_any`：同一地点的其他可接受写法（如带括号后缀的全称/简称），提取命中任一即算地址正确。
- `category` 分类：
  | 分类 | 含义 |
  |---|---|
  | `standard` | 标准格式（主流快递公司模板） |
  | `nonstandard-code` | 非标准取件码格式（如 `B26`） |
  | `hard` | 口语化/无签名/冒号变体等难例（LLM 兜底提取的目标场景） |
  | `negative` | 负样本 |

**脱敏声明**：数据集全部为虚构地名/驿站名（如「临江大学」「临江广场丰巢」），模板结构参考真实快递短信格式，不包含任何真实个人、学校或地址信息。数据集由 `generate_dataset.ps1`（固定随机种子，可复现）按模板组合生成，可在其基础上人工扩充。

## 指标定义

| 指标 | 定义 |
|---|---|
| 解析成功率 | 标注含取件码的样本中，解析器产出非空取件码的比例 |
| 精确识别率 | 取件码**且**地址（含 address_any）都匹配标注的比例 |
| 负样本误提取率 | 负样本中被提取出取件码的比例（越低越好） |
| 分组 pairwise P/R/F1 | 对所有已提取样本两两判断"是否同组"：预测同组=提取地址相同（`--llm` 时为归一化后地址），真值同组=station 相同 |
| 产生的组数 | 精确匹配分组产生的组数 vs 真实驿站组数（> 真实值 = 同站被拆分） |
| 兜底恢复率 | `--llm`：正则失败的正样本中被 LLM 正确恢复（码+地址全对）的比例 |

## 当前基线（2026-10-20，v0.4.0，模型 deepseek-ai/DeepSeek-V3）

| 指标 | 正则引擎 | + LLM 兜底/归一化 | 说明 |
|---|---|---|---|
| 精确识别率（整体） | 58.1% | **91.9%** | 兜底恢复 42/42（正则失败样本全部正确恢复） |
| 其中 standard 类 | 86.8% | — | 主流快递模板 |
| 其中 nonstandard-code 类 | 0% | 全部由兜底恢复 | 如 `B26` 格式取件码 |
| 其中 hard 类 | 25% | 全部由兜底恢复 | 口语化/无签名难例 |
| 负样本误提取率 | 8.3% | — | 「快递100」签名中的数字被误提取 |
| 分组 pairwise F1 | 59.6% | **95.0%** | 组数 21 → 13（真实 6 组） |
| LLM 调用成本 | — | 4 批请求 | 136 样本仅 4 次批量调用 |

完整报告：`benchmark/results/eval_2026-10-20_offline.md`（离线）、`benchmark/results/eval_2026-10-20_llm.md`（含 LLM 对照）。

## 复用与扩展

- 整个目录自包含：只需 `sms_parser.dart`（纯 Dart）与 `llm_prompts.dart`/`sms_fallback_extractor.dart`（LLM 部分），不依赖 Flutter 插件，`dart run` 直接可跑。
- 加样本：往 jsonl 追加一行即可（保持 `station`/`label`/`category` 字段）；用 `--audit` 校验标注质量。
- 对比其他提取方案：实现 `Extraction? Function(String body)`，替换 `extractByRegex` 复用 `runRegexEval` 的指标计算。
