# 取件超时通知功能实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 当取件码短信超过 72 小时未标记已取时，通过本地通知提醒用户。

**Architecture:** 使用 WorkManager 周期性后台任务（每 2 小时），复用现有 `SmsProcessor` 解析短信，通过 SharedPreferences 记录已通知状态避免重复提醒。功能默认关闭，用户在设置中手动开启。

**Tech Stack:** Flutter, workmanager, flutter_local_notifications, shared_preferences, permission_handler

---

## 文件结构

| 文件 | 职责 |
|------|------|
| `lib/config/constants.dart` | 新增存储键名常量 |
| `lib/services/storage_service.dart` | 新增 `pickupOverdueEnabled` 和 `notifiedOverdueIds` 的读写方法 |
| `lib/providers/settings_provider.dart` | 新增 `pickupOverdueEnabledProvider` |
| `lib/services/notification_service.dart` | 新增 `pickup_overdue` 通知渠道和 `showOverdueNotification()` 方法 |
| `lib/services/background_service.dart` | **新增**。WorkManager 注册、任务回调、超时检查逻辑 |
| `lib/screens/mine/advanced_settings_screen.dart` | 新增取件超时通知开关 UI |
| `lib/main.dart` | 启动时调用 `BackgroundService.register()` |
| `pubspec.yaml` | 添加 `workmanager` 依赖 |
| `android/app/src/main/AndroidManifest.xml` | 添加 `POST_NOTIFICATIONS`、`FOREGROUND_SERVICE` 权限 |

---

### Task 1: 添加 workmanager 依赖

**Files:**
- Modify: `pubspec.yaml`

- [ ] **Step 1: 在 pubspec.yaml 的 dependencies 中添加 workmanager**

```yaml
  # 后台任务
  workmanager: ^0.5.2
```

添加位置：在 `permission_handler` 行之后。

- [ ] **Step 2: 运行 flutter pub get**

Run: `flutter pub get`
Expected: 依赖安装成功，无报错

- [ ] **Step 3: Commit**

```bash
git add pubspec.yaml pubspec.lock
git commit -m "deps: add workmanager for background pickup overdue check"
```

---

### Task 2: 添加 Android 权限声明

**Files:**
- Modify: `android/app/src/main/AndroidManifest.xml`

- [ ] **Step 1: 在现有权限声明后添加新权限**

在 `android/app/src/main/AndroidManifest.xml` 的 `<uses-permission android:name="android.permission.READ_SMS" />` 行之后添加：

```xml
    <!-- 后台任务权限 -->
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
```

- [ ] **Step 2: Commit**

```bash
git add android/app/src/main/AndroidManifest.xml
git commit -m "feat: add POST_NOTIFICATIONS and FOREGROUND_SERVICE permissions"
```

---

### Task 3: 添加存储键名常量

**Files:**
- Modify: `lib/config/constants.dart`

- [ ] **Step 1: 在 AppConstants 类中添加新常量**

在 `lib/config/constants.dart` 的 `static const String keyHideCompletedPickups = 'hide_completed_pickups';` 行之后添加：

```dart
  static const String keyPickupOverdueEnabled = 'pickup_overdue_enabled';
  static const String keyNotifiedOverdueIds = 'notified_overdue_ids';
```

- [ ] **Step 2: Commit**

```bash
git add lib/config/constants.dart
git commit -m "feat: add storage key constants for pickup overdue notification"
```

---

### Task 4: 添加 StorageService 读写方法

**Files:**
- Modify: `lib/services/storage_service.dart`

- [ ] **Step 1: 在 StorageService 类末尾（`close()` 方法之前）添加两个方法组**

在 `lib/services/storage_service.dart` 的 `// --- Hive (快递数据) ---` 注释之前添加：

```dart
  // --- 取件超时通知 ---

  Future<bool> getPickupOverdueEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(AppConstants.keyPickupOverdueEnabled) ?? false;
  }

  Future<void> setPickupOverdueEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.keyPickupOverdueEnabled, value);
  }

  Future<List<String>> getNotifiedOverdueIds() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(AppConstants.keyNotifiedOverdueIds) ?? [];
  }

  Future<void> setNotifiedOverdueIds(List<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(AppConstants.keyNotifiedOverdueIds, ids);
  }
```

- [ ] **Step 2: Commit**

```bash
git add lib/services/storage_service.dart
git commit -m "feat: add storage methods for pickup overdue notification"
```

---

### Task 5: 添加 settings provider

**Files:**
- Modify: `lib/providers/settings_provider.dart`

- [ ] **Step 1: 在 settings_provider.dart 中添加 provider 和 notifier**

在 `lib/providers/settings_provider.dart` 的 `deletedPackagesProvider` 定义之前添加：

```dart
final pickupOverdueEnabledProvider =
    StateNotifierProvider<PickupOverdueEnabledNotifier, bool>((ref) {
  return PickupOverdueEnabledNotifier(ref.read(storageServiceProvider));
});
```

在文件末尾的 `AutoCleanNotifier` 类之后添加：

```dart
class PickupOverdueEnabledNotifier extends StateNotifier<bool> {
  final StorageService _storage;
  PickupOverdueEnabledNotifier(this._storage) : super(false) {
    _load();
  }

  Future<void> _load() async {
    state = await _storage.getPickupOverdueEnabled();
  }

  Future<void> set(bool value) async {
    await _storage.setPickupOverdueEnabled(value);
    state = value;
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/providers/settings_provider.dart
git commit -m "feat: add pickupOverdueEnabledProvider"
```

---

### Task 6: 扩展 NotificationService

**Files:**
- Modify: `lib/services/notification_service.dart`

- [ ] **Step 1: 在 NotificationService 类中添加新方法**

在 `lib/services/notification_service.dart` 的 `showSignedNotification` 方法之后添加：

```dart
  Future<void> showOverdueNotification({
    required String code,
    required String address,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'pickup_overdue',
      '取件超时提醒',
      channelDescription: '取件码超过72小时未取件时发送提醒',
      importance: Importance.high,
      priority: Priority.high,
    );
    const details = NotificationDetails(android: androidDetails);

    final title = '取件超时提醒';
    final body = '您的取件码 $code'
        '${address.isNotEmpty && address != '未知地址' ? '（$address）' : ''}'
        ' 已超过 72 小时未取件，请尽快处理';

    await _plugin.show(
      code.hashCode,
      title,
      body,
      details,
    );
  }
```

- [ ] **Step 2: Commit**

```bash
git add lib/services/notification_service.dart
git commit -m "feat: add showOverdueNotification method"
```

---

### Task 7: 创建 BackgroundService

**Files:**
- Create: `lib/services/background_service.dart`

- [ ] **Step 1: 创建 BackgroundService 类**

创建文件 `lib/services/background_service.dart`，内容如下：

```dart
import 'package:workmanager/workmanager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/constants.dart';
import '../utils/sms_parser.dart';
import '../utils/sms_processor.dart';
import 'notification_service.dart';

const _taskName = 'pickupOverdueCheck';
const _overdueHours = 72;

void _callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task != _taskName) return true;

    try {
      final prefs = await SharedPreferences.getInstance();
      final enabled =
          prefs.getBool(AppConstants.keyPickupOverdueEnabled) ?? false;
      if (!enabled) return true;

      final completedIds = prefs.getStringList('completedIds') ?? [];
      final notifiedIds =
          prefs.getStringList(AppConstants.keyNotifiedOverdueIds) ?? [];
      final notifiedSet = notifiedIds.toSet();

      final parser = SmsParser();
      final result = await SmsProcessor.loadAndProcess(
        parser: parser,
        completedIds: completedIds,
      );

      final now = DateTime.now();
      final deadline = now.subtract(const Duration(hours: _overdueHours));
      final newNotified = <String>[...notifiedIds];
      bool changed = false;

      for (final smsData in result.successful) {
        final smsTime =
            DateTime.fromMillisecondsSinceEpoch(smsData.sms.timestamp);
        if (smsTime.isAfter(deadline)) continue;
        if (smsData.isCompleted) continue;

        final key = smsData.id;
        if (notifiedSet.contains(key)) continue;

        await NotificationService().showOverdueNotification(
          code: smsData.code,
          address: smsData.address,
        );
        newNotified.add(key);
        changed = true;
      }

      if (changed) {
        await prefs.setStringList(
            AppConstants.keyNotifiedOverdueIds, newNotified);
      }

      return true;
    } catch (_) {
      return true;
    }
  });
}

class BackgroundService {
  static bool _registered = false;

  static Future<void> register() async {
    if (_registered) return;

    await Workmanager().initialize(
      _callbackDispatcher,
      isInDebugMode: false,
    );

    await Workmanager().registerPeriodicTask(
      _taskName,
      _taskName,
      frequency: const Duration(hours: 2),
      existingWorkPolicy: ExistingWorkPolicy.keep,
      constraints: Constraints(
        requiresBatteryNotLow: true,
      ),
    );

    _registered = true;
  }

  static Future<void> unregister() async {
    await Workmanager().cancelByUniqueName(_taskName);
    _registered = false;
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/services/background_service.dart
git commit -m "feat: add BackgroundService with WorkManager pickup overdue check"
```

---

### Task 8: 集成 BackgroundService 到 main.dart

**Files:**
- Modify: `lib/main.dart`

- [ ] **Step 1: 在 main.dart 中导入 BackgroundService**

在 `lib/main.dart` 的 import 区域添加：

```dart
import 'services/background_service.dart';
```

- [ ] **Step 2: 在 main 函数中注册后台任务**

在 `lib/main.dart` 的 `await NotificationService().init();` 行之后添加：

```dart
  await BackgroundService.register();
```

- [ ] **Step 3: Commit**

```bash
git add lib/main.dart
git commit -m "feat: register BackgroundService on app startup"
```

---

### Task 9: 添加功能开关 UI

**Files:**
- Modify: `lib/screens/mine/advanced_settings_screen.dart`

- [ ] **Step 1: 在"取件码"设置区块中添加开关**

在 `lib/screens/mine/advanced_settings_screen.dart` 的 `build` 方法中，找到取件码区块的 `Card` widget：

```dart
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.rule, color: Colors.blue),
                  title: const Text('自定义解析规则'),
                  subtitle: const Text('查看和管理自定义的取件码解析规则'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const _CustomRulesScreen()),
                    );
                  },
                ),
              ],
            ),
          ),
```

替换为：

```dart
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Column(
              children: [
                _PickupOverdueSwitch(),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.rule, color: Colors.blue),
                  title: const Text('自定义解析规则'),
                  subtitle: const Text('查看和管理自定义的取件码解析规则'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const _CustomRulesScreen()),
                    );
                  },
                ),
              ],
            ),
          ),
```

- [ ] **Step 2: 添加 _PickupOverdueSwitch widget**

在 `AdvancedSettingsScreen` 类定义之前添加：

```dart
class _PickupOverdueSwitch extends ConsumerStatefulWidget {
  const _PickupOverdueSwitch();

  @override
  ConsumerState<_PickupOverdueSwitch> createState() =>
      _PickupOverdueSwitchState();
}

class _PickupOverdueSwitchState extends ConsumerState<_PickupOverdueSwitch> {
  bool _requesting = false;

  Future<void> _onChanged(bool value) async {
    if (value) {
      setState(() => _requesting = true);
      try {
        final notificationStatus =
            await Permission.notification.request();
        final smsStatus = await Permission.sms.request();

        if (!mounted) return;

        if (!notificationStatus.isGranted || !smsStatus.isGranted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('需要通知和短信权限才能使用此功能')),
          );
          setState(() => _requesting = false);
          return;
        }

        await ref.read(pickupOverdueEnabledProvider.notifier).set(true);
        await BackgroundService.register();
      } finally {
        if (mounted) setState(() => _requesting = false);
      }
    } else {
      await ref.read(pickupOverdueEnabledProvider.notifier).set(false);
      await BackgroundService.unregister();
    }
  }

  @override
  Widget build(BuildContext context) {
    final enabled = ref.watch(pickupOverdueEnabledProvider);
    return SwitchListTile(
      title: const Text('取件超时提醒'),
      subtitle: Text(_requesting
          ? '正在请求权限...'
          : '取件码超过72小时未取件时发送通知'),
      value: enabled,
      onChanged: _requesting ? null : _onChanged,
      secondary: Icon(
        enabled ? Icons.notifications_active : Icons.notifications_outlined,
        color: enabled ? Colors.orange : Colors.grey,
      ),
    );
  }
}
```

- [ ] **Step 3: 添加缺失的 import**

在 `lib/screens/mine/advanced_settings_screen.dart` 的 import 区域添加：

```dart
import 'package:permission_handler/permission_handler.dart';
import '../../services/background_service.dart';
```

- [ ] **Step 4: Commit**

```bash
git add lib/screens/mine/advanced_settings_screen.dart
git commit -m "feat: add pickup overdue notification toggle in advanced settings"
```

---

### Task 10: 验证与清理

- [ ] **Step 1: 运行静态分析**

Run: `flutter analyze`
Expected: 无错误（warnings 可接受）

- [ ] **Step 2: 运行测试**

Run: `flutter test`
Expected: 所有测试通过

- [ ] **Step 3: 手动验证流程**

1. 打开 app → 我的 → 高级设置 → 取件码区块
2. 开启"取件超时提醒" → 应弹出权限请求
3. 授权后开关应保持开启状态
4. 关闭开关 → 开关应关闭
5. 重新打开 app → 开关状态应持久化

- [ ] **Step 4: Final commit**

```bash
git add -A
git commit -m "feat: complete pickup overdue 72h notification feature"
```
