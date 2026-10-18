import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/constants.dart';
import '../models/package.dart';

class StorageService {
  late Box<Package> _packageBox;
  late Box<Package> _deletedBox;

  Future<void> init() async {
    await Hive.initFlutter();
    Hive.registerAdapter(PackageAdapter());
    _packageBox = await Hive.openBox<Package>(AppConstants.hiveBoxName);
    _deletedBox = await Hive.openBox<Package>(AppConstants.hiveDeletedBoxName);
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

  Future<bool> getAutoSave() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(AppConstants.keyAutoSave) ?? true;
  }

  Future<void> setAutoSave(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.keyAutoSave, value);
  }

  Future<bool> getAutoClean() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(AppConstants.keyAutoClean) ?? true;
  }

  Future<void> setAutoClean(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.keyAutoClean, value);
  }

  Future<int> getThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(AppConstants.keyThemeMode) ?? 0;
  }

  Future<void> setThemeMode(int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(AppConstants.keyThemeMode, value);
  }

  Future<bool> getAutoCheckUpdate() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(AppConstants.keyAutoCheckUpdate) ?? true;
  }

  Future<void> setAutoCheckUpdate(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.keyAutoCheckUpdate, value);
  }

  Future<bool> getHideCompletedPickups() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(AppConstants.keyHideCompletedPickups) ?? true;
  }

  Future<void> setHideCompletedPickups(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.keyHideCompletedPickups, value);
  }

  // --- 取件超时通知 ---

  Future<bool> getPickupOverdueEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(AppConstants.keyPickupOverdueEnabled) ?? false;
  }

  Future<void> setPickupOverdueEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.keyPickupOverdueEnabled, value);
  }

  Future<List<String>> getNotifiedOverdueIds() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(AppConstants.keyNotifiedOverdueIds) ?? [];
  }

  Future<void> setNotifiedOverdueIds(List<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(AppConstants.keyNotifiedOverdueIds, ids);
  }

  // --- SharedPreferences (LLM 配置与缓存) ---

  Future<bool> getLlmEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(AppConstants.keyLlmEnabled) ?? false;
  }

  Future<void> setLlmEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.keyLlmEnabled, value);
  }

  Future<String> getLlmBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(AppConstants.keyLlmBaseUrl) ??
        'https://api.deepseek.com/v1';
  }

  Future<void> setLlmBaseUrl(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.keyLlmBaseUrl, value);
  }

  Future<String> getLlmModel() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(AppConstants.keyLlmModel) ?? 'deepseek-chat';
  }

  Future<void> setLlmModel(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.keyLlmModel, value);
  }

  Future<String> getLlmApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(AppConstants.keyLlmApiKey) ?? '';
  }

  Future<void> setLlmApiKey(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.keyLlmApiKey, value);
  }

  Future<Map<String, String>> getLlmAddressMap() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(AppConstants.keyLlmAddressMap);
    if (raw == null || raw.isEmpty) return {};
    // 脏缓存（损坏 JSON / 非对象）一律降级为空 Map，绝不让缓存读取异常阻塞调用方
    try {
      final decoded = json.decode(raw);
      if (decoded is! Map) return {};
      // 只保留值为字符串的条目，过滤脏条目
      return {
        for (final entry in decoded.entries)
          if (entry.value is String)
            entry.key.toString(): entry.value as String,
      };
    } catch (_) {
      return {};
    }
  }

  Future<void> setLlmAddressMap(Map<String, String> map) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.keyLlmAddressMap, json.encode(map));
  }

  Future<Map<String, Map<String, String>>> getLlmEtaCache() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(AppConstants.keyLlmEtaCache);
    if (raw == null || raw.isEmpty) return {};
    // 脏缓存（损坏 JSON / 非对象）一律降级为空 Map，绝不让缓存读取异常阻塞调用方
    try {
      final decoded = json.decode(raw);
      if (decoded is! Map) return {};
      final result = <String, Map<String, String>>{};
      for (final entry in decoded.entries) {
        final value = entry.value;
        // 外层值必须是 Map，内层只保留字符串字段，
        // 过滤 null 等脏条目，避免 null.toString() 产生 "null" 字符串穿透
        if (value is! Map) continue;
        final inner = <String, String>{};
        for (final e in value.entries) {
          if (e.value is String) inner[e.key.toString()] = e.value as String;
        }
        result[entry.key.toString()] = inner;
      }
      return result;
    } catch (_) {
      return {};
    }
  }

  Future<void> setLlmEtaCache(Map<String, Map<String, String>> cache) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.keyLlmEtaCache, json.encode(cache));
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

  // --- 回收站 ---

  List<Package> getDeletedPackages() => _deletedBox.values.toList();

  Future<void> addToRecycleBin(Package package) async {
    await _deletedBox.put(package.id, package);
  }

  Future<void> restoreFromRecycleBin(String id) async {
    final pkg = _deletedBox.get(id);
    if (pkg != null) {
      await _packageBox.put(id, pkg);
      await _deletedBox.delete(id);
    }
  }

  Future<void> permanentlyDelete(String id) async {
    await _deletedBox.delete(id);
  }

  Future<void> clearRecycleBin() async {
    await _deletedBox.clear();
  }

  Future<void> close() async {
    await Hive.close();
  }
}
