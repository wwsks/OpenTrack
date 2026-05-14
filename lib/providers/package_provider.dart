import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/package.dart';
import '../models/tracking_info.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';
import 'settings_provider.dart';
import 'package:uuid/uuid.dart';

final apiServiceProvider = Provider<ApiService>((ref) => ApiService());

final notificationServiceProvider =
    Provider<NotificationService>((ref) => NotificationService());

final allPackagesProvider =
    StateNotifierProvider<PackageListNotifier, List<Package>>((ref) {
  return PackageListNotifier(ref);
});

final unsignedPackagesProvider = Provider<List<Package>>((ref) {
  return ref.watch(allPackagesProvider).where((p) => !p.isSigned).toList();
});

final signedPackagesProvider = Provider<List<Package>>((ref) {
  return ref.watch(allPackagesProvider).where((p) => p.isSigned).toList();
});

class PackageListNotifier extends StateNotifier<List<Package>> {
  final Ref _ref;
  PackageListNotifier(this._ref) : super([]) {
    _load();
  }

  void _load() {
    final storage = _ref.read(storageServiceProvider);
    state = storage.getAllPackages();
  }

  Future<void> refresh() async {
    _load();
  }

  Future<void> addPackage({
    required String trackingNumber,
    required String companyCode,
    required String companyName,
    String? phone,
    String? remark,
  }) async {
    final storage = _ref.read(storageServiceProvider);
    final pkg = Package(
      id: const Uuid().v4(),
      trackingNumber: trackingNumber,
      companyCode: companyCode,
      companyName: companyName,
      phone: phone,
      remark: remark,
    );
    await storage.addPackage(pkg);
    _load();
  }

  Future<void> deletePackage(String id) async {
    final storage = _ref.read(storageServiceProvider);
    await storage.deletePackage(id);
    _load();
  }

  Future<TrackingInfo?> querySingle(Package pkg) async {
    final apiKey = _ref.read(apiKeyProvider);
    final customer = _ref.read(customerProvider);
    if (apiKey == null || customer == null) return null;

    final api = _ref.read(apiServiceProvider);
    final info = await api.queryPackage(
      trackingNumber: pkg.trackingNumber,
      companyCode: pkg.companyCode,
      apiKey: apiKey,
      customer: customer,
      phone: pkg.phone,
    );
    return info;
  }

  Future<void> refreshSingle(Package pkg) async {
    final info = await querySingle(pkg);
    if (info == null || info.data.isEmpty) return;

    final storage = _ref.read(storageServiceProvider);
    pkg.lastContext = info.data.first.context;
    pkg.lastTime = DateTime.tryParse(info.data.first.time) ?? DateTime.now();
    pkg.status = info.state;
    if (info.isSigned && !pkg.isSigned) {
      pkg.isSigned = true;
      final notification = _ref.read(notificationServiceProvider);
      await notification.showSignedNotification(
        trackingNumber: pkg.trackingNumber,
        remark: pkg.remark,
      );
    }
    await storage.updatePackage(pkg);
    _load();
  }

  Future<void> refreshAllUnsigned() async {
    final unsigned = state.where((p) => !p.isSigned).toList();
    for (final pkg in unsigned) {
      await refreshSingle(pkg);
      await Future.delayed(const Duration(seconds: 2));
    }
  }

  Future<(TrackingInfo?, String?)> autoDetectAndAdd({
    required String trackingNumber,
    String? phone,
    String? remark,
  }) async {
    final apiKey = _ref.read(apiKeyProvider);
    final customer = _ref.read(customerProvider);
    if (apiKey == null || customer == null) {
      return (null, '请先配置 API Key 和 Customer');
    }

    final api = _ref.read(apiServiceProvider);
    final info = await api.autoDetectAndQuery(
      trackingNumber: trackingNumber,
      apiKey: apiKey,
      customer: customer,
      phone: phone,
    );

    if (info == null || info.data.isEmpty) {
      return (null, '未找到快递信息，请检查单号或手动选择快递公司');
    }

    return (info, null);
  }

  Future<(TrackingInfo?, String?)> manualQueryAndAdd({
    required String trackingNumber,
    required String companyCode,
    required String companyName,
    String? phone,
    String? remark,
  }) async {
    final apiKey = _ref.read(apiKeyProvider);
    final customer = _ref.read(customerProvider);
    if (apiKey == null || customer == null) {
      return (null, '请先配置 API Key 和 Customer');
    }

    final api = _ref.read(apiServiceProvider);
    try {
      final info = await api.queryPackage(
        trackingNumber: trackingNumber,
        companyCode: companyCode,
        apiKey: apiKey,
        customer: customer,
        phone: phone,
      );
      return (info, null);
    } catch (e) {
      return (null, '查询失败: $e');
    }
  }
}
