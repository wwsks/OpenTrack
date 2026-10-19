import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/theme.dart';
import '../../providers/package_provider.dart';
import '../../models/package.dart';
import '../detail/detail_screen.dart';
import '../../widgets/package_card.dart';
import '../../animations/animations.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(allPackagesProvider.notifier).refreshAllUnsigned();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 三个 tab 的数量徽标数据源（徽标样式见 _TabCountBadge）
    final unsignedCount = ref.watch(unsignedPackagesProvider).length;
    final signedCount = ref.watch(signedPackagesProvider).length;
    final allCount = ref.watch(allPackagesProvider).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('快递列表'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(child: _TabCountBadge(label: '未签收', count: unsignedCount)),
            Tab(child: _TabCountBadge(label: '已签收', count: signedCount)),
            Tab(child: _TabCountBadge(label: '全部', count: allCount)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _PackageList(
            packages: ref.watch(unsignedPackagesProvider),
            onRefresh: () =>
                ref.read(allPackagesProvider.notifier).refreshAllUnsigned(),
          ),
          _PackageList(
            packages: ref.watch(signedPackagesProvider),
            onRefresh: () =>
                ref.read(allPackagesProvider.notifier).refresh(),
          ),
          _PackageList(
            packages: ref.watch(allPackagesProvider),
            onRefresh: () =>
                ref.read(allPackagesProvider.notifier).refreshAllUnsigned(),
          ),
        ],
      ),
    );
  }
}

class _PackageList extends ConsumerWidget {
  final List<Package> packages;
  final Future<void> Function() onRefresh;

  const _PackageList({required this.packages, required this.onRefresh});

  void _showDeleteMenu(BuildContext context, WidgetRef ref, Package pkg) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.textSecondary(context),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading:
                  const Icon(Icons.delete_outline, color: AppTheme.accentRed),
              title: const Text('删除快递',
                  style: TextStyle(color: AppTheme.accentRed)),
              subtitle: Text(pkg.trackingNumber),
              onTap: () {
                Navigator.pop(ctx);
                ref.read(allPackagesProvider.notifier).deletePackage(pkg.id);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (packages.isEmpty) {
      // 空状态也保持可滚动，下拉刷新在空列表同样可用
      return RefreshIndicator(
        onRefresh: onRefresh,
        displacement: 40,
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Center(
                child: AppTheme.emptyState(
                  context,
                  icon: Icons.inbox_outlined,
                  message: '暂无快递',
                ),
              ),
            ),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      displacement: 40,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: packages.length,
        itemBuilder: (context, index) {
          final pkg = packages[index];
          return StaggeredListAnimation(
            index: index,
            delay: const Duration(milliseconds: 40),
            child: Dismissible(
              key: Key(pkg.id),
              direction: DismissDirection.endToStart,
              dismissThresholds: const {
                DismissDirection.endToStart: 0.3,
              },
              movementDuration: const Duration(milliseconds: 400),
              resizeDuration: const Duration(milliseconds: 300),
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 24),
                // 与 Card 主题 margin 对齐，滑动背景与卡片同形
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.accentRed.withValues(alpha: 0.8),
                      AppTheme.accentRed,
                    ],
                    stops: const [0.0, 0.6],
                  ),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Icon(Icons.delete_outline, color: Colors.white, size: 22),
                    SizedBox(width: 8),
                    Text('删除',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              confirmDismiss: (direction) async {
                HapticFeedback.mediumImpact();
                return true;
              },
              onDismissed: (_) {
                ref.read(allPackagesProvider.notifier).deletePackage(pkg.id);
              },
              child: GestureDetector(
                onLongPress: () {
                  HapticFeedback.heavyImpact();
                  _showDeleteMenu(context, ref, pkg);
                },
                child: PackageCard(
                  package: pkg,
                  onTap: () {
                    Navigator.push(
                      context,
                      SlideFadeRoute(
                        page: DetailScreen(package: pkg),
                      ),
                    );
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// tab 数量徽标：tab 文案 + 12% 当前标签色底的小 pill，
/// 颜色跟随 TabBar 选中/未选中态（从 DefaultTextStyle 取标签色），三个 tab 样式统一
class _TabCountBadge extends StatelessWidget {
  final String label;
  final int count;

  const _TabCountBadge({required this.label, required this.count});

  @override
  Widget build(BuildContext context) {
    final color = DefaultTextStyle.of(context).style.color ??
        AppTheme.accent(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label),
        const SizedBox(width: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              fontSize: AppTheme.fontCaption,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}
