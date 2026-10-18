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
  static const String keyHideCompletedPickups = 'hide_completed_pickups';
  static const String keyPickupOverdueEnabled = 'pickup_overdue_enabled';
  static const String keyNotifiedOverdueIds = 'notified_overdue_ids';
  static const String keyLlmEnabled = 'llm_enabled';
  static const String keyLlmBaseUrl = 'llm_base_url';
  static const String keyLlmModel = 'llm_model';
  static const String keyLlmApiKey = 'llm_api_key';
  static const String keyLlmAddressMap = 'llm_address_map';
  static const String keyLlmEtaCache = 'llm_eta_cache';
  static const String hiveDeletedBoxName = 'deleted_packages_box';
  static const String hiveBoxName = 'packages_box';

  // 查询间隔（秒）
  static const int queryIntervalSeconds = 2;
}
