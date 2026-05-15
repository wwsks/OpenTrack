import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'config/theme.dart';
import 'providers/settings_provider.dart';
import 'screens/home/home_screen.dart';
import 'screens/search/search_screen.dart';
import 'screens/pickup/pickup_screen.dart';
import 'screens/mine/mine_screen.dart';
import 'services/notification_service.dart';
import 'services/storage_service.dart';
import 'services/update_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final storage = StorageService();
  await storage.init();

  await NotificationService().init();

  runApp(
    ProviderScope(
      overrides: [
        storageServiceProvider.overrideWithValue(storage),
      ],
      child: const OpenTrackApp(),
    ),
  );
}

class OpenTrackApp extends ConsumerWidget {
  const OpenTrackApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeModeIndex = ref.watch(themeModeProvider);
    final themeMode = switch (themeModeIndex) {
      1 => ThemeMode.light,
      2 => ThemeMode.dark,
      _ => ThemeMode.system,
    };

    return MaterialApp(
      title: 'OpenTrack',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      home: const MainScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
  int _currentIndex = 0;

  final _screens = const [
    HomeScreen(),
    SearchScreen(),
    PickupScreen(),
    MineScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkForUpdate();
    });
  }

  Future<void> _checkForUpdate() async {
    final autoCheck = await ref.read(storageServiceProvider).getAutoCheckUpdate();
    if (!autoCheck || !mounted) return;

    final updateInfo = await UpdateService.checkForUpdate();
    if (updateInfo != null && mounted) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('发现新版本 v${updateInfo.latestVersion}'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('更新内容：',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(updateInfo.releaseNotes.isNotEmpty
                    ? updateInfo.releaseNotes
                    : '暂无更新说明'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('稍后再说'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                UpdateService.openDownloadPage(updateInfo.downloadUrl);
              },
              child: const Text('去下载'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: '首页',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.search),
            label: '查快递',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.qr_code),
            label: '取件码',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: '我的',
          ),
        ],
      ),
    );
  }
}
