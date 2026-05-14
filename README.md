# 自邮查

查快递的 Android 应用。输入单号就能查，快递到了会通知你。

## 能做什么

- 输入单号查快递当前位置，支持自动识别快递公司（覆盖 3050 家）
- 三个列表切换：未签收、已签收、全部
- 添加快递时可以填物品备注，方便区分多个包裹
- 后台每小时自动检查，签收了手机会弹通知
- 每次打开 app 自动刷新最新状态

## 怎么用

1. 先去[快递100](https://www.kuaidi100.com/)注册企业版，拿到授权 Key 和 Customer
2. 打开 app，在"我的"页面填入 Key 和 Customer
3. 在"查快递"页面输入单号，查询后点"添加到我的快递"
4. 之后在首页就能看到所有快递的状态，不用再操心

## 技术栈

| 用途 | 方案 |
|------|------|
| 框架 | Flutter 3.x |
| 状态管理 | Riverpod |
| 网络请求 | dio |
| 数据存储 | Hive + SharedPreferences |
| 后台任务 | workmanager |
| 消息通知 | flutter_local_notifications |
| 签名算法 | crypto (MD5) |

## 项目结构

```
lib/
├── main.dart                 # 入口
├── config/                   # 常量、主题
├── models/                   # 数据模型
├── services/                 # API、存储、通知、后台
├── providers/                # Riverpod 状态管理
├── screens/                  # 页面（首页/查快递/详情/我的）
├── widgets/                  # 可复用组件
└── utils/                    # 签名、快递公司工具
```

## 文档

- [设计文档](docs/DESIGN.md) — 整体设计和数据模型
- [快递100 API 文档](docs/kuaidi100_api.md) — 接口说明和状态码
