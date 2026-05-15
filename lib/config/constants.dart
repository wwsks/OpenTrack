class AppConstants {
  // 快递100 API
  static const String apiBaseUrl = 'https://poll.kuaidi100.com/poll/query.do';
  static const String signType = 'MD5';

  // 存储键名
  static const String keyApiKey = 'kuaidi100_api_key';
  static const String keyCustomer = 'kuaidi100_customer';
  static const String keyAutoSave = 'auto_save_enabled';
  static const String keyAutoClean = 'auto_clean_enabled';
  static const String keyThemeMode = 'theme_mode';
  static const String keyAutoCheckUpdate = 'auto_check_update';
  static const String hiveDeletedBoxName = 'deleted_packages_box';
  static const String hiveBoxName = 'packages_box';

  // 查询间隔（秒）
  static const int queryIntervalSeconds = 2;
}
