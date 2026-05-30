# AGENTS.md

This file provides guidance to AI coding agents working on this repository.

## Project Overview

自邮取 (OpenTrack) — Android 快递查询应用，通过快递100 API 查询快递状态，支持短信取件码提取、后台轮询和到件推送。

## Common Commands

```bash
# 安装依赖
flutter pub get

# 代码生成（修改 Hive model 后必须重新运行）
dart run build_runner build --delete-conflicting-outputs

# 静态分析
flutter analyze

# 运行测试
flutter test

# 构建 release APK
flutter build apk --release
```

Flutter SDK 位于 `C:\dev\flutter`，如未加入 PATH，需先 `export PATH="/c/dev/flutter/bin:$PATH"`。

## Architecture

### 状态管理：Riverpod

- `storageServiceProvider` 在 main.dart 中通过 override 注入 StorageService 实例，所有 provider 依赖它
- `settings_provider.dart` 管理 API Key / Customer（SharedPreferences）和各种设置开关
- `package_provider.dart` 管理快递列表（Hive），提供增删改查和刷新逻辑
- 快递列表分为三个派生 provider：`allPackagesProvider`、`unsignedPackagesProvider`、`signedPackagesProvider`

### 数据存储

- **SharedPreferences**：存 API Key、Customer 和各种设置（简单 key-value）
- **Hive**：存 Package 对象（需要 `@HiveType` 注解 + build_runner 生成 adapter）
- StorageService 同时封装了两种存储，统一对外暴露接口

### 快递100 API 签名

签名算法在 `lib/utils/sign_util.dart`：`MD5(param + key + customer)` 转 32 位大写。
`param` 是 JSON 字符串，包含 com（快递公司编码）、num（单号）等字段。

### 快递公司自动识别

`assets/data/companies.json` 内置 3050 家快递公司编码。自动识别逻辑在 `ApiService.autoDetectAndQuery`，逐个尝试常见快递公司查询，返回第一个有结果的。

### 短信取件码解析

`lib/utils/sms_parser.dart` 是核心解析引擎，使用正则从短信中提取取件码和驿站地址。
`lib/utils/sms_processor.dart` 是处理流水线：读取短信 → 解析 → 按地址分组 → 去重 → 标记已完成。
支持自定义解析规则，存储在 SharedPreferences 中。

### 动画系统

`lib/animations/` 目录包含 Telegram 风格动画工具：

| 文件 | 用途 |
|------|------|
| `page_transitions.dart` | 页面转场（从右侧滑入 + 上一页视差效果） |
| `staggered_list.dart` | 列表项交错入场动画（淡入 + 上滑 + 缩放） |
| `animated_nav_bar.dart` | 自定义底部导航栏（选中项展开显示文字） |
| `pressable_card.dart` | 按压反馈卡片（缩放 + 触觉反馈） |

### 主题

`lib/config/theme.dart` 包含 Telegram 风格的浅色/深色双主题。
浅色主色 `#3390EC`，深色背景 `#0E1621`。
文字颜色必须显式设置，不能依赖 `ColorScheme.fromSeed` 的默认值。

## Key Files

| 文件 | 职责 |
|------|------|
| `lib/main.dart` | 初始化存储/通知，注入 Riverpod，自定义底部导航栏 + 页面切换动画 |
| `lib/config/theme.dart` | Telegram 风格浅色/深色主题 |
| `lib/config/constants.dart` | API URL、存储 key、查询间隔等常量 |
| `lib/services/api_service.dart` | 快递100 API 调用 + 自动识别 |
| `lib/services/storage_service.dart` | Hive + SharedPreferences 统一存储 |
| `lib/services/notification_service.dart` | 本地通知（签收提醒） |
| `lib/services/update_service.dart` | GitHub Release 版本检测 |
| `lib/providers/package_provider.dart` | 核心业务逻辑：查询、添加、刷新、删除 |
| `lib/providers/settings_provider.dart` | 所有设置项的 StateNotifier |
| `lib/models/package.dart` | Package 数据模型（Hive 序列化） |
| `lib/models/tracking_info.dart` | API 响应模型 |
| `lib/screens/pickup/pickup_screen.dart` | 取件码页面（短信读取 + 分组显示） |
| `lib/screens/home/home_screen.dart` | 快递列表页面（三个 tab） |
| `lib/screens/search/search_screen.dart` | 查快递页面（单个/批量查询） |
| `lib/screens/detail/detail_screen.dart` | 快递详情 + 物流时间线 |
| `lib/screens/mine/mine_screen.dart` | 我的页面（设置入口） |
| `lib/widgets/package_card.dart` | 快递卡片组件（按压动画 + 状态指示器） |
| `lib/utils/sms_parser.dart` | 短信解析引擎（正则提取取件码） |
| `lib/utils/sms_processor.dart` | 短信处理流水线 |
| `lib/utils/sign_util.dart` | API 签名（MD5） |
| `lib/utils/company_util.dart` | 快递公司数据加载 + 搜索 |
| `lib/utils/company_logo.dart` | 快递公司 logo 映射 |

## Conventions

- 状态管理统一用 Riverpod，不要混用其他方案
- 数据持久化用 Hive（结构化数据）或 SharedPreferences（简单配置）
- 页面转场使用 `SlideFadeRoute`，不要用默认的 `MaterialPageRoute`
- 列表项使用 `StaggeredListAnimation` 包裹实现入场动画
- 卡片使用 `PressableCard` 包裹实现按压反馈
- 主题颜色从 `AppTheme` 静态常量获取，不要硬编码
- 版本号在三个地方维护：`pubspec.yaml`、`update_service.dart` 的 `_currentVersion`、`mine_screen.dart` 的版本显示

## Version Release Checklist

更新版本号时需要修改：
1. `pubspec.yaml` 的 `version` 字段
2. `lib/services/update_service.dart` 的 `_currentVersion` 常量
3. `lib/screens/mine/mine_screen.dart` 的版本显示文本
