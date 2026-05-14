import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/constants.dart';
import '../models/package.dart';

class StorageService {
  late Box<Package> _packageBox;

  Future<void> init() async {
    await Hive.initFlutter();
    Hive.registerAdapter(PackageAdapter());
    _packageBox = await Hive.openBox<Package>(AppConstants.hiveBoxName);
  }

  // --- SharedPreferences (API 配置) ---

  Future<String?> getApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(AppConstants.keyApiKey);
  }

  Future<void> setApiKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.keyApiKey, key);
  }

  Future<String?> getCustomer() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(AppConstants.keyCustomer);
  }

  Future<void> setCustomer(String customer) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.keyCustomer, customer);
  }

  // --- Hive (快递数据) ---

  List<Package> getAllPackages() => _packageBox.values.toList();

  List<Package> getUnsignedPackages() =>
      _packageBox.values.where((p) => !p.isSigned).toList();

  List<Package> getSignedPackages() =>
      _packageBox.values.where((p) => p.isSigned).toList();

  Package? getPackage(String id) => _packageBox.get(id);

  Future<void> addPackage(Package package) async {
    await _packageBox.put(package.id, package);
  }

  Future<void> updatePackage(Package package) async {
    await package.save();
  }

  Future<void> deletePackage(String id) async {
    await _packageBox.delete(id);
  }

  Future<void> close() async {
    await Hive.close();
  }
}
