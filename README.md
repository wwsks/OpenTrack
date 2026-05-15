# 自邮查

查快递的 Android 应用。输入单号就能查，快递到了会通知你。

## 功能

- 输入单号查快递位置，自动识别快递公司（覆盖 3050 家）
- 三个列表切换：未签收、已签收、全部
- 批量查询，一次查多个快递
- 添加快递时可以填物品备注
- 后台每小时自动检查，签收了弹通知
- 每次打开 app 自动刷新
- 从短信里读取取件码，按快递公司分组显示
- 跳转淘宝/拼多多身份码取件
- 深色模式，支持跟随系统
- 删除的快递进回收站，可以恢复

## 怎么用

1. 去[快递100 API](https://api.kuaidi100.com)注册账号，拿到授权 Key 和 Customer
2. 打开 app，在"我的"页面填入 Key 和 Customer
3. 在"查快递"页面输入单号查询
4. 首页能看到所有快递状态，下拉刷新

## 技术栈

| 用途 | 方案 |
|------|------|
| 框架 | Flutter 3.x |
| 状态管理 | Riverpod |
| 网络请求 | dio |
| 数据存储 | Hive + SharedPreferences |
| 后台任务 | workmanager |
| 消息通知 | flutter_local_notifications |
| 短信读取 | flutter_sms_inbox |
| 签名算法 | crypto (MD5) |

## 项目结构

```
lib/
├── main.dart                 # 入口
├── config/                   # 常量、主题
├── models/                   # 数据模型
├── services/                 # API、存储、通知
├── providers/                # Riverpod 状态管理
├── screens/                  # 页面
├── widgets/                  # 可复用组件
└── utils/                    # 签名、短信解析
```
