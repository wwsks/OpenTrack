class AppConstants {
  // 快递100 API
  static const String apiBaseUrl = 'https://poll.kuaidi100.com/poll/query.do';
  static const String signType = 'MD5';

  // 存储键名
  static const String keyApiKey = 'kuaidi100_api_key';
  static const String keyCustomer = 'kuaidi100_customer';
  static const String keyAutoSave = 'auto_save_enabled';
  static const String hiveBoxName = 'packages_box';

  // 后台任务
  static const String taskPollPackages = 'com.opentrack.poll_packages';
  static const int pollIntervalMinutes = 60;

  // 查询间隔（秒）
  static const int queryIntervalSeconds = 2;
}
