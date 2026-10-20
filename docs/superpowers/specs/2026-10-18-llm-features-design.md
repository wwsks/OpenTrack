# LLM 增强功能设计（地址归一化 / 取件清单 / ETA 估算）

日期：2026-10-18
状态：待评审

## 背景与问题

取件码页面按地址字符串**精确匹配**分组（`sms_processor.dart` 的 `parcelsMap = <String, ParcelData>{}`）。同一实体驿站因短信格式微差（如「临江南区菜鸟驿站」vs「临江大学南区菜鸟驿站」）被拆成多组，分组结果不符合用户直觉。

正则提取本身没有问题，问题在**归一化缺失**。本地模糊匹配（编辑距离/包含关系）阈值难调、误合并难纠正，不做。

## 目标

1. **地址归一化**：用大模型把同一驿站的不同表述归一为标准驿站名，分组合并正确。
2. **取件清单生成**：一键生成"到站一次性取完"的简短取件清单。
3. **ETA 估算**：在快递详情页展示 LLM 基于物流轨迹的送达时间估算（明确标注为估算）。

## 非目标

- 失败短信兜底提取、自然语言查快递（本轮不做）
- 本地模糊匹配规则引擎
- 后台任务（WorkManager）中的 LLM 调用（后台不联网调 LLM，保持现有逻辑）
- 真实物流预测模型 / 历史数据统计时效

## 总体架构

LLM 是**增强层**：坏了就退回现状，绝不阻塞核心功能。所有功能共用一个服务层。

### 新增文件

| 文件 | 职责 |
|------|------|
| `lib/services/llm_service.dart` | OpenAI 兼容 `chat/completions` 调用（dio）。请求组装、30s 超时、错误分类（网络/鉴权/限流/解析）、支持强制 JSON 输出、从回复中提取 JSON 块 |
| `lib/providers/llm_provider.dart` | LLM 配置 StateNotifier（enabled / baseUrl / model / apiKey），存 SharedPreferences，沿用 `settings_provider.dart` 模式 |
| `lib/utils/address_normalizer.dart` | 归一化核心：查缓存 → 未命中地址**批量一次** LLM 调用 → 写缓存。接口可注入 fake 便于测试 |
| `lib/utils/llm_prompts.dart` | 三个功能的 prompt 模板常量 |
| `lib/screens/mine/llm_settings_screen.dart` | 大模型设置页 |

### 改造文件

| 文件 | 改动 |
|------|------|
| `lib/config/constants.dart` | 新增 LLM 相关存储 key 常量 |
| `lib/utils/sms_processor.dart` | `process()` 增加可选 `normalizer` 参数；分组 key 改用标准驿站名 |
| `lib/screens/pickup/pickup_screen.dart` | 顶栏新增「生成取件清单」按钮（LLM 未启用时隐藏） |
| `lib/screens/detail/detail_screen.dart` | 新增「预计送达（估算）」卡片（LLM 未启用时隐藏） |
| `lib/screens/mine/mine_screen.dart` | 新增「大模型」设置入口 |

## 接入层

**OpenAI 兼容可配置**：设置页可填 base URL、模型名、API Key。默认 base URL `https://api.deepseek.com/v1`，模型名留默认示例 `deepseek-chat`，用户可改为任何兼容服务（硅基流动、月之暗面、智谱、本地 Ollama 等）。

### 存储（SharedPreferences）

| key | 类型 | 说明 |
|-----|------|------|
| `llm_enabled` | bool | 总开关，默认 false |
| `llm_base_url` | String | 默认 `https://api.deepseek.com/v1` |
| `llm_model` | String | 默认 `deepseek-chat` |
| `llm_api_key` | String | 用户自填 |
| `llm_address_map` | String(JSON) | 归一化映射缓存 `{"原地址": "标准驿站名"}` |
| `llm_eta_cache` | String(JSON) | ETA 缓存 `{"轨迹文本hash": {"estimate":..., "reason":...}}` |

## 功能一：地址归一化

### 流程

1. 短信解析成功后，收集去重的地址列表。
2. 查 `llm_address_map` 缓存：命中直接用标准名。
3. 未命中的地址**合并为一次** LLM 调用（天然避免限流与重复消耗），要求返回 JSON：`{"原地址": "标准驿站名"}`。
4. 结果写入缓存（失败不写，下次自动重试）。
5. `parcelsMap` 的 key = 标准驿站名，分组标题显示标准名。

### 归一化规则（写入 system prompt）

- 同一物理站点的不同表述归一到**信息最全**的一个名称（如优先含「菜鸟驿站/妈妈驿站/快递超市/丰巢/服务站」等通名的完整写法）。
- 不同物理站点**绝不合并**（如两个不同的菜鸟驿站门店）。
- 拿不准时保留原名，不强行合并（宁可不合并，不可误合并）。

### 调用与降级

- 后台任务（`background_service.dart`）**不传 normalizer**，不触发 LLM 调用。
- LLM 未启用/调用失败/JSON 不合格式 → 本次按原地址精确分组（即现状行为），不写缓存、不弹错。
- 同一地址永久缓存，一个新驿站一生只调用一次。

## 功能二：取件清单生成

- 入口：取件码页顶栏按钮，LLM 未启用时隐藏。
- 输入：所有**未完成**取件码（地址、取件码、柜号），提取为结构化列表，不含手机号/单号/短信全文。
- 输出：纯文本清单 —— 按驿站分组，一行一个驿站，站内按柜号顺序排列取件码，末尾附总计。目标是到驿站后能一次性取完。
- 展示：底部弹层显示清单文本，提供「复制到剪贴板」按钮（不加新依赖；系统分享列为后续可选项）。
- 失败：弹层内显示「生成失败，点击重试」。不缓存（清单随未完成状态变化）。

## 功能三：ETA 估算

- 位置：详情页物流轨迹卡片下方，标题「预计送达（估算）」，副文本注明「AI 估算，仅供参考」。
- 输入：快递公司名 + 最新轨迹节点文本与时间（不含手机号/单号）。
- 输出 JSON：`{"estimate": "预计X月X日前后送达", "reason": "一句话依据"}`，展示 estimate 为主文本、reason 为灰色小字。
- 缓存：以最新轨迹文本 hash 为 key 缓存结果；轨迹更新（hash 变化）才重新调用；按需调用（打开详情页时），失败显示「生成失败，点击重试」。
- 明确定位：这是基于"当前环节 + 城市间常规时效"的**估算**，不是承诺。

## 错误处理矩阵

| 场景 | 行为 |
|------|------|
| 未配置/未启用 | 归一化跳过（现状分组）；清单按钮与 ETA 卡片隐藏；设置页引导配置 |
| 归一化调用失败 | 按原地址分组，不写缓存，下次自动重试，不打扰用户 |
| 清单/ETA 调用失败 | 功能区内「生成失败，点击重试」 |
| 返回 JSON 不合格式 | 该批次视为失败走降级，不写脏缓存 |
| 401 鉴权失败 | 设置页标红提示 API Key 无效 |

统一 30s 超时；批量归一化单次请求；结果缓存杜绝重复调用。

## 隐私

设置页明示，并遵守：

- 发往模型服务的数据**仅限**：驿站地址文本（归一化）、未完成取件码+地址（清单）、快递公司+轨迹节点文本（ETA）。
- **不发送**：手机号、快递单号、快递100 API Key、用户任何身份信息。
- 页内注明「以上数据将发送至你配置的模型服务地址」。

## 测试策略

| 测试 | 覆盖 |
|------|------|
| `test/address_normalizer_test.dart` | 缓存命中、批量归一化、失败降级不写缓存、脏 JSON 拒绝 |
| `test/llm_service_test.dart` | 请求组装、错误分类（401/超时/网络）、JSON 提取（mock HTTP） |
| `test/sms_processor_test.dart` | 注入 fake normalizer，验证分组按标准名合并、normalizer 为 null 时保持现状 |
| `test/widget_test.dart` | 修复现有失败（包 ProviderScope + override） |
| 手工 E2E | 用硅基流动真实 API Key 实测三个功能（base URL `https://api.siliconflow.cn/v1`） |

## 发布

完成后按 AGENTS.md 版本清单三处同步升版本（建议 minor 升到 0.4.0）。
