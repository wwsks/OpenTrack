import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/storage_service.dart';

final storageServiceProvider = Provider<StorageService>((ref) {
  throw UnimplementedError('Must be overridden in main');
});

final apiKeyProvider = StateNotifierProvider<ApiKeyNotifier, String?>((ref) {
  return ApiKeyNotifier(ref.read(storageServiceProvider));
});

final customerProvider =
    StateNotifierProvider<CustomerNotifier, String?>((ref) {
  return CustomerNotifier(ref.read(storageServiceProvider));
});

final hasApiConfigProvider = Provider<bool>((ref) {
  final key = ref.watch(apiKeyProvider);
  final customer = ref.watch(customerProvider);
  return key != null && key.isNotEmpty && customer != null && customer.isNotEmpty;
});

final autoSaveProvider = StateNotifierProvider<AutoSaveNotifier, bool>((ref) {
  return AutoSaveNotifier(ref.read(storageServiceProvider));
});

final autoCleanProvider = StateNotifierProvider<AutoCleanNotifier, bool>((ref) {
  return AutoCleanNotifier(ref.read(storageServiceProvider));
});

class ApiKeyNotifier extends StateNotifier<String?> {
  final StorageService _storage;
  ApiKeyNotifier(this._storage) : super(null) {
    _load();
  }

  Future<void> _load() async {
    state = await _storage.getApiKey();
  }

  Future<void> set(String key) async {
    await _storage.setApiKey(key);
    state = key;
  }
}

class CustomerNotifier extends StateNotifier<String?> {
  final StorageService _storage;
  CustomerNotifier(this._storage) : super(null) {
    _load();
  }

  Future<void> _load() async {
    state = await _storage.getCustomer();
  }

  Future<void> set(String customer) async {
    await _storage.setCustomer(customer);
    state = customer;
  }
}

class AutoSaveNotifier extends StateNotifier<bool> {
  final StorageService _storage;
  AutoSaveNotifier(this._storage) : super(true) {
    _load();
  }

  Future<void> _load() async {
    state = await _storage.getAutoSave();
  }

  Future<void> set(bool value) async {
    await _storage.setAutoSave(value);
    state = value;
  }
}

class AutoCleanNotifier extends StateNotifier<bool> {
  final StorageService _storage;
  AutoCleanNotifier(this._storage) : super(true) {
    _load();
  }

  Future<void> _load() async {
    state = await _storage.getAutoClean();
  }

  Future<void> set(bool value) async {
    await _storage.setAutoClean(value);
    state = value;
  }
}
