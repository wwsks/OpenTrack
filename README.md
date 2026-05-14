# OpenTrack

快递查询 Android 应用，基于 Flutter 框架，通过快递100 API 查询快递状态。

## 功能

- 实时查询快递位置
- 快递列表管理（未签收/已签收/全部）
- 到件本地推送通知
- 后台自动轮询（每小时）
- 快递公司自动识别

## 技术栈

- Flutter 3.x
- Riverpod 状态管理
- dio HTTP 请求
- Hive 本地存储
- workmanager 后台任务
- flutter_local_notifications 本地通知

## 文档

- [设计文档](docs/DESIGN.md)
- [快递100 API 文档](docs/kuaidi100_api.md)
