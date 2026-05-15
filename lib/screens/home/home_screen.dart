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
        child: ListTile(
          leading: const Icon(Icons.delete_outline, color: Colors.red),
          title: const Text('删除快递', style: TextStyle(color: Colors.red)),
          subtitle: Text(pkg.trackingNumber),
          onTap: () {
            Navigator.pop(ctx);
            ref.read(allPackagesProvider.notifier).deletePackage(pkg.id);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (packages.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('暂无快递', style: TextStyle(color: Colors.grey, fontSize: 16)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: packages.length,
        itemBuilder: (context, index) {
          final pkg = packages[index];
          return Dismissible(
            key: Key(pkg.id),
            direction: DismissDirection.endToStart,
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.red.shade300, Colors.red],
                  stops: const [0.0, 0.5],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Icon(Icons.delete_outline, color: Colors.white, size: 22),
                  SizedBox(width: 6),
                  Text('删除',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w500)),
                ],
              ),
            ),
            onDismissed: (_) {
              ref.read(allPackagesProvider.notifier).deletePackage(pkg.id);
            },
            child: GestureDetector(
              onLongPress: () {
                HapticFeedback.mediumImpact();
                _showDeleteMenu(context, ref, pkg);
              },
              child: PackageCard(
                package: pkg,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => DetailScreen(package: pkg)),
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
