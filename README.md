# 自邮查

Android 快递查询应用。输入单号查位置，快递到了推通知，取件码从短信里自动捞。

## 功能

查快递：
- 输入单号查询，自动识别快递公司（3050 家）
- 未签收、已签收、全部，三个列表切换
- 批量查询，一次查多个
- 物品备注，方便区分包裹
- 删除的快递进回收站，能恢复

取件码：
- 从短信自动读取取件码，按快递公司分组
- 标记已取后可隐藏
- 一键跳转淘宝/拼多多身份码

其他：
- 深色模式，跟随系统或手动切换
- 打开 app 自动刷新，签收弹通知
- 检测到新版本会提示更新
- 自定义解析规则，处理格式特殊的短信

## 使用

1. 去 [快递100 API](https://api.kuaidi100.com) 注册，拿到 Key 和 Customer
2. 打开 app，"我的"页面填入 Key 和 Customer
3. "查快递"页面输入单号查询
4. 快递列表页下拉刷新

## 技术栈

| 用途 | 方案 |
|------|------|
| 框架 | Flutter 3.x |
| 状态管理 | Riverpod |
| 网络 | dio |
| 存储 | Hive + SharedPreferences |
| 通知 | flutter_local_notifications |
| 短信 | flutter_sms_inbox |

## 项目结构

```
lib/
├── main.dart
├── config/          # 常量、主题
├── models/          # 数据模型
├── services/        # API、存储、通知
├── providers/       # 状态管理
├── screens/         # 页面
├── widgets/         # 组件
└── utils/           # 签名、短信解析
```
