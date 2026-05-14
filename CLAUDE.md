# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

自邮查 (OpenTrack) — Android 快递查询应用，通过快递100 API 查询快递状态，支持后台轮询和到件推送。

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

# 构建 APK
flutter build apk
```

Flutter SDK 位于 `C:\dev\flutter`，如未加入 PATH，需先 `export PATH="/c/dev/flutter/bin:$PATH"`。

## Architecture

### 状态管理：Riverpod

- `storageServiceProvider` 在 main.dart 中通过 override 注入 StorageService 实例，所有 provider 依赖它
- `settings_provider.dart` 管理 API Key / Customer（SharedPreferences）
- `package_provider.dart` 管理快递列表（Hive），提供增删改查和刷新逻辑
- 快递列表分为三个派生 provider：`allPackagesProvider`、`unsignedPackagesProvider`、`signedPackagesProvider`

### 数据存储

- **SharedPreferences**：存 API Key 和 Customer（简单 key-value）
- **Hive**：存 Package 对象（需要 `@HiveType` 注解 + build_runner 生成 adapter）
- StorageService 同时封装了两种存储，统一对外暴露接口

### 快递100 API 签名

签名算法在 `lib/utils/sign_util.dart`：`MD5(param + key + customer)` 转 32 位大写。
`param` 是 JSON 字符串，包含 com（快递公司编码）、num（单号）等字段。

### 后台任务

`workmanager` 每小时执行 `callbackDispatcher`，遍历未签收快递逐个查询，状态变为签收时触发 `flutter_local_notifications` 通知。后台任务独立于主 isolate，需要自己初始化 StorageService。

### 快递公司自动识别

`assets/data/companies.json` 内置 3050 家快递公司编码。自动识别逻辑在 `ApiService.autoDetectAndQuery`，逐个尝试常见快递公司查询，返回第一个有结果的。

## Key Files

| 文件 | 职责 |
|------|------|
| `lib/main.dart` | 初始化存储/通知/后台任务，注入 Riverpod，底部导航 |
| `lib/services/api_service.dart` | 快递100 API 调用 + 自动识别 |
| `lib/services/background_service.dart` | workmanager 回调，轮询未签收快递 |
| `lib/providers/package_provider.dart` | 核心业务逻辑：查询、添加、刷新、删除 |
| `lib/models/package.dart` | Package 数据模型（Hive 序列化） |
