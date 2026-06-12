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

  Future<void> showOverdueNotification({
    required String code,
    required String address,
    required String smsId,
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
      smsId.hashCode,
      title,
      body,
      details,
    );
  }
}
