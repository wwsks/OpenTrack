import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);
    await _plugin.initialize(initSettings);
  }

  Future<void> showSignedNotification({
    required String trackingNumber,
    String? remark,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'package_signed',
      '快递签收通知',
      channelDescription: '快递签收时发送通知',
      importance: Importance.high,
      priority: Priority.high,
    );
    const details = NotificationDetails(android: androidDetails);

    final title = '快递已签收';
    final body = remark != null && remark.isNotEmpty
        ? '您的快递 $remark($trackingNumber) 已签收'
        : '您的快递 $trackingNumber 已签收';

    await _plugin.show(
      trackingNumber.hashCode,
      title,
      body,
      details,
    );
  }
}
