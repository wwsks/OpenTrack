# 取件超时通知功能设计

## 概述

当快递取件码短信超过 72 小时未被标记为"已取"时，通过本地通知提醒用户。

## 需求

- **触发条件**：取件码短信的 timestamp 距今超过 72 小时 + 用户未标记已取 + 未发过超时通知
- **检查频率**：每 2 小时（WorkManager 周期性任务）
- **通知策略**：每个取件码只通知一次
- **功能开关**：默认关闭，用户主动开启，开启时请求权限

## 架构

```
用户开启功能开关
  → 请求 POST_NOTIFICATIONS + SMS 权限
  → 注册 WorkManager 周期任务（每 2 小时）

后台任务执行：
  → 读取系统短信（最近 7 天）
  → SmsProcessor.loadAndProcess() 解析取件码
  → 筛选：未完成 + timestamp 超过 72 小时 + 未通知过
  → 发送本地通知
  → 记录到 notifiedOverdueIds
```

## 数据模型

不修改 `Package` 模型，不新增 Hive 存储。所有状态通过 SharedPreferences 管理：

| Key | 类型 | 用途 |
|-----|------|------|
| `completedIds` | `List<String>` | 已取件的 SMS ID（已有） |
| `notifiedOverdueIds` | `List<String>` | 已发送超时通知的 SMS ID（新增） |
| `pickup_overdue_enabled` | `bool` | 功能开关（新增） |

SMS ID 格式：`${sms.id}_${sms.timestamp}`（与现有 `completedIds` 一致）。

## 新增/修改文件

| 文件 | 变更 |
|------|------|
| `lib/services/background_service.dart` | 新增。WorkManager 注册、任务回调 |
| `lib/services/notification_service.dart` | 新增 `showOverdueNotification()` 和 `pickup_overdue` 通知渠道 |
| `lib/providers/settings_provider.dart` | 新增 `pickupOverdueEnabled` 设置项 |
| `lib/screens/mine/mine_screen.dart` | 新增功能开关 UI |
| `lib/main.dart` | 启动时调用 `BackgroundService.register()` |
| `pubspec.yaml` | 添加 `workmanager` 依赖 |
| `android/app/src/main/AndroidManifest.xml` | 添加 `POST_NOTIFICATIONS`、`FOREGROUND_SERVICE` 权限 |

## WorkManager 配置

- 任务名：`pickupOverdueCheck`
- 周期：2 小时
- `requiresNetworkConnectivity: false`（只读本地短信）
- `existingPolicy: keep`（避免重复注册）

## 通知内容

- 通知渠道：`pickup_overdue`（取件超时提醒）
- 标题：`取件超时提醒`
- 内容：`您的取件码 XXX（驿站地址）已超过 72 小时未取件，请尽快处理`
- 重要性：`Importance.high`

## 权限处理

Android 13+ 需要 `POST_NOTIFICATIONS` 运行时权限。采用 opt-in 策略：

1. 用户在"我的"页面看到开关（默认关闭）
2. 开启时依次请求 `POST_NOTIFICATIONS` 和 `SMS` 权限
3. 权限通过 → 注册后台任务
4. 权限被拒 → 提示用户，开关回弹为关闭
5. 关闭时取消后台任务

## 兼容性考虑

- 中国 OEM（小米/华为/OPPO）可能限制后台任务，但 2 小时的宽限期足够容忍延迟
- 如果用户未授予权限，功能不生效，不影响其他功能
- 如果 SMS 权限被撤销，后台任务静默跳过，不报错
