import 'package:workmanager/workmanager.dart';
import '../config/constants.dart';
import 'api_service.dart';
import 'notification_service.dart';
import 'storage_service.dart';

void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task != AppConstants.taskPollPackages) return true;

    final storage = StorageService();
    await storage.init();

    final api = ApiService();
    final notification = NotificationService();
    await notification.init();

    final apiKey = await storage.getApiKey();
    final customer = await storage.getCustomer();
    if (apiKey == null || customer == null) return true;

    final unsigned = storage.getUnsignedPackages();
    for (final pkg in unsigned) {
      try {
        final info = await api.queryPackage(
          trackingNumber: pkg.trackingNumber,
          companyCode: pkg.companyCode,
          apiKey: apiKey,
          customer: customer,
          phone: pkg.phone,
        );
        if (info.data.isNotEmpty) {
          pkg.lastContext = info.data.first.context;
          pkg.lastTime = DateTime.tryParse(info.data.first.time) ?? DateTime.now();
          pkg.status = info.state;
          if (info.isSigned) {
            pkg.isSigned = true;
            await notification.showSignedNotification(
              trackingNumber: pkg.trackingNumber,
              remark: pkg.remark,
            );
          }
          await storage.updatePackage(pkg);
        }
      } catch (_) {}
      await Future.delayed(
          const Duration(seconds: AppConstants.queryIntervalSeconds));
    }
    await storage.close();
    return true;
  });
}

class BackgroundService {
  static Future<void> init() async {
    await Workmanager().initialize(callbackDispatcher, isInDebugMode: false);
  }

  static Future<void> registerPeriodicTask() async {
    await Workmanager().registerPeriodicTask(
      AppConstants.taskPollPackages,
      AppConstants.taskPollPackages,
      frequency: const Duration(minutes: AppConstants.pollIntervalMinutes),
      constraints: Constraints(networkType: NetworkType.connected),
    );
  }

  static Future<void> cancelAll() async {
    await Workmanager().cancelAll();
  }
}
