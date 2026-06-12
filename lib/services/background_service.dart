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
          smsId: smsData.id,
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
        networkType: NetworkType.not_required,
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
