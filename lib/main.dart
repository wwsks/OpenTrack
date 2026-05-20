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
import 'animations/animations.dart';

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

class _MainScreenState extends ConsumerState<MainScreen>
    with TickerProviderStateMixin {
  int _currentIndex = 0;
  late AnimationController _pageTransitionController;
  late Animation<double> _pageFadeAnimation;
  late Animation<Offset> _pageSlideAnimation;

  final _screens = const [
    PickupScreen(),
    HomeScreen(),
    SearchScreen(),
    MineScreen(),
  ];

  static const _navItems = [
    NavBarItem(
      icon: Icons.qr_code_outlined,
      activeIcon: Icons.qr_code,
      label: '取件码',
    ),
    NavBarItem(
      icon: Icons.local_shipping_outlined,
      activeIcon: Icons.local_shipping,
      label: '快递列表',
    ),
    NavBarItem(
      icon: Icons.search_outlined,
      activeIcon: Icons.search,
      label: '查快递',
    ),
    NavBarItem(
      icon: Icons.person_outline,
      activeIcon: Icons.person,
      label: '我的',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pageTransitionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _pageFadeAnimation = CurvedAnimation(
      parent: _pageTransitionController,
      curve: Curves.easeOutCubic,
    );
    _pageSlideAnimation = Tween<Offset>(
      begin: const Offset(0.04, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _pageTransitionController,
      curve: Curves.easeOutCubic,
    ));
    _pageTransitionController.value = 1.0;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkForUpdate();
    });
  }

  @override
  void dispose() {
    _pageTransitionController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    if (index == _currentIndex) return;
    setState(() => _currentIndex = index);
    _pageTransitionController.forward(from: 0.0);
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
      body: FadeTransition(
        opacity: _pageFadeAnimation,
        child: SlideTransition(
          position: _pageSlideAnimation,
          child: IndexedStack(
            index: _currentIndex,
            children: _screens,
          ),
        ),
      ),
      bottomNavigationBar: AnimatedNavBar(
        currentIndex: _currentIndex,
        onTap: _onPageChanged,
        items: _navItems,
      ),
    );
  }
}
