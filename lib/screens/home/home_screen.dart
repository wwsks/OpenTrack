import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/package_provider.dart';
import '../../models/package.dart';
import '../detail/detail_screen.dart';
import '../../widgets/package_card.dart';

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
    return Scaffold(
      appBar: AppBar(
        title: const Text('快递列表'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '未签收'),
            Tab(text: '已签收'),
            Tab(text: '全部'),
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
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('删除快递', style: TextStyle(color: Colors.red)),
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
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_outlined, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text('暂无快递',
                style: TextStyle(color: Colors.grey.shade400, fontSize: 16)),
          ],
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
          return Dismissible(
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
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.red.shade300, Colors.red.shade500],
                  stops: const [0.0, 0.6],
                ),
                borderRadius: BorderRadius.circular(14),
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
                    MaterialPageRoute(
                      builder: (context) => DetailScreen(package: pkg),
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}
