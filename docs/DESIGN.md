# OpenTrack - 快递查询 Android 应用设计文档

## 一、功能概述

基于 Flutter 框架的 Android 快递查询应用，通过快递100 API 查询快递状态。

### 核心功能
1. **实时查询** - 输入快递单号查询当前位置
2. **快递列表** - 分类展示：未签收 / 已签收 / 全部
3. **到件推送** - 快递签收后本地通知
4. **后台轮询** - 每小时自动检查未签收快递状态
5. **打开刷新** - 每次打开应用自动刷新所有快递状态
6. **物品备注** - 添加快递时可选填物品信息作为备注

### 底部导航
| 标签 | 功能 |
|------|------|
| 首页 | 快递列表（未签收/已签收/全部） |
| 查快递 | 输入单号查询，支持自动识别快递公司 |
| 我的 | API 设置、关于 |

## 二、技术栈

| 组件 | 方案 |
|------|------|
| 框架 | Flutter 3.x |
| 状态管理 | Riverpod |
| HTTP 请求 | dio |
| API Key 存储 | shared_preferences |
| 快递数据存储 | hive |
| 后台任务 | workmanager |
| 本地通知 | flutter_local_notifications |
| MD5 签名 | crypto |

## 三、页面设计

### 3.1 首页 - 快递列表
- 顶部 TabBar：未签收（默认）/ 已签收 / 全部
- 列表项显示：快递公司图标、单号、备注（如有）、最新状态、时间
- 下拉刷新
- 左滑删除
- 点击进入详情页

### 3.2 查快递
- 输入框：快递单号（支持粘贴）
- 快递公司选择（可选，支持搜索）
- 备注输入框：物品信息（选填，如"手机壳"、"书籍"等）
- 查询按钮
- 查询结果展示
- "添加到我的快递" 按钮

### 3.3 我的
- API 设置（key、customer）
- 快递公司编码表（查看用）
- 关于

### 3.4 快递详情
- 快递基本信息（单号、公司、状态、备注）
- 状态时间线（data 数组）
- 当前位置

## 四、数据模型

### 4.1 Package（Hive 存储）
```dart
@HiveType(typeId: 0)
class Package {
  @HiveField(0) String id;           // 唯一标识
  @HiveField(1) String trackingNumber; // 快递单号
  @HiveField(2) String companyCode;   // 快递公司编码
  @HiveField(3) String companyName;   // 快递公司名称
  @HiveField(4) String status;        // 状态：collected/transit/delivering/signed/issue
  @HiveField(5) String lastContext;   // 最新轨迹描述
  @HiveField(6) DateTime lastTime;    // 最新更新时间
  @HiveField(7) DateTime addedTime;   // 添加时间
  @HiveField(8) bool isSigned;        // 是否已签收
  @HiveField(9) String? phone;        // 手机号（顺丰等需要）
  @HiveField(10) String? remark;      // 物品备注（选填）
}
```

### 4.2 TrackingInfo（查询结果）
```dart
class TrackingInfo {
  final String companyCode;
  final String trackingNumber;
  final String state;        // 0=在途, 1=揽收, 3=签收, 5=派件...
  final String message;
  final List<TrackingEvent> data;
}

class TrackingEvent {
  final String context;      // 轨迹描述
  final String time;         // 原始时间
  final String ftime;        // 格式化时间
  final String? status;      // 状态名
  final String? location;    // 当前位置
}
```

## 五、API 签名逻辑

```dart
String generateSign(String param, String key, String customer) {
  final content = param + key + customer;
  final bytes = utf8.encode(content);
  final digest = md5.convert(bytes);
  return digest.toString().toUpperCase();
}
```

## 六、后台轮询策略

### 6.1 workmanager 配置
- 任务名：`com.opentrack.poll_packages`
- 频率：每 60 分钟
- 约束：网络可用时执行

### 6.2 轮询逻辑
1. 从 Hive 读取所有未签收快递
2. 逐个调用 API 查询状态
3. 若状态变为"签收"(state=3)，触发本地通知
4. 更新 Hive 中的数据
5. 控制查询频率，每个单号间隔 2 秒

### 6.3 通知内容
- 标题：`快递已签收`
- 内容：`您的快递 {单号} 已签收`（如有备注则显示：`您的快递 {备注}({单号}) 已签收`）
- 点击通知：打开应用对应详情页

## 七、快递公司自动识别

### 方案
1. 用户输入单号后，尝试用常见快递公司（圆通、中通、韵达等）查询
2. 返回结果成功的即为对应公司
3. 将 3050 家快递公司数据内置为 JSON 文件

### 快递公司数据来源
从 `快递100快递公司标准编码.xlsx` 提取，保存为 `assets/data/companies.json`

## 八、目录结构

```
lib/
├── main.dart                    # 入口
├── app.dart                     # MaterialApp 配置
│
├── config/
│   ├── constants.dart           # 常量
│   └── theme.dart               # 主题
│
├── models/
│   ├── package.dart             # Package 模型
│   ├── tracking_info.dart       # TrackingInfo 模型
│   └── package.g.dart           # Hive 生成
│
├── services/
│   ├── api_service.dart         # 快递100 API 调用
│   ├── storage_service.dart     # Hive + SharedPreferences
│   ├── notification_service.dart # 本地通知
│   └── background_service.dart  # 后台任务
│
├── providers/
│   ├── package_provider.dart    # 快递状态管理
│   ├── settings_provider.dart   # 设置状态管理
│   └── search_provider.dart     # 查询状态管理
│
├── screens/
│   ├── home/
│   │   ├── home_screen.dart     # 首页
│   │   └── package_list.dart    # 快递列表
│   ├── search/
│   │   ├── search_screen.dart   # 查快递
│   │   └── result_screen.dart   # 查询结果
│   ├── detail/
│   │   └── detail_screen.dart   # 快递详情
│   └── mine/
│       ├── mine_screen.dart     # 我的
│       └── settings_screen.dart # API 设置
│
├── widgets/
│   ├── package_card.dart        # 快递卡片
│   ├── timeline_item.dart       # 时间线项
│   └── company_picker.dart      # 快递公司选择器
│
└── utils/
    ├── sign_util.dart           # 签名工具
    └── company_util.dart        # 快递公司工具

assets/
└── data/
    └── companies.json           # 快递公司编码表
```

## 九、实现顺序

1. **Phase 1 - 基础框架**
   - Flutter 项目初始化
   - 依赖配置
   - 底部导航
   - 主题配置

2. **Phase 2 - 核心功能**
   - API 签名工具
   - API 调用服务
   - 查快递页面
   - 快递详情页

3. **Phase 3 - 数据持久化**
   - Hive 模型配置
   - 快递列表存储
   - API Key 存储
   - 首页列表展示

4. **Phase 4 - 后台与通知**
   - workmanager 配置
   - 本地通知
   - 签收检测与推送

5. **Phase 5 - 优化完善**
   - 快递公司自动识别
   - 打开自动刷新
   - 错误处理
   - UI 打磨
