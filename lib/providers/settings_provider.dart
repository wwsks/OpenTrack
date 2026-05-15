import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/package.dart';
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

final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, int>((ref) {
  return ThemeModeNotifier(ref.read(storageServiceProvider));
});

final autoCheckUpdateProvider =
    StateNotifierProvider<AutoCheckUpdateNotifier, bool>((ref) {
  return AutoCheckUpdateNotifier(ref.read(storageServiceProvider));
});

final hideCompletedPickupsProvider =
    StateNotifierProvider<HideCompletedPickupsNotifier, bool>((ref) {
  return HideCompletedPickupsNotifier(ref.read(storageServiceProvider));
});

final deletedPackagesProvider =
    StateNotifierProvider<DeletedPackagesNotifier, List<Package>>((ref) {
  return DeletedPackagesNotifier(ref.read(storageServiceProvider));
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

class HideCompletedPickupsNotifier extends StateNotifier<bool> {
  final StorageService _storage;
  HideCompletedPickupsNotifier(this._storage) : super(false) {
    _load();
  }

  Future<void> _load() async {
    state = await _storage.getHideCompletedPickups();
  }

  Future<void> set(bool value) async {
    await _storage.setHideCompletedPickups(value);
    state = value;
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

class ThemeModeNotifier extends StateNotifier<int> {
  final StorageService _storage;
  ThemeModeNotifier(this._storage) : super(0) {
    _load();
  }

  Future<void> _load() async {
    state = await _storage.getThemeMode();
  }

  Future<void> set(int value) async {
    await _storage.setThemeMode(value);
    state = value;
  }
}

class AutoCheckUpdateNotifier extends StateNotifier<bool> {
  final StorageService _storage;
  AutoCheckUpdateNotifier(this._storage) : super(true) {
    _load();
  }

  Future<void> _load() async {
    state = await _storage.getAutoCheckUpdate();
  }

  Future<void> set(bool value) async {
    await _storage.setAutoCheckUpdate(value);
    state = value;
  }
}

class DeletedPackagesNotifier extends StateNotifier<List<Package>> {
  final StorageService _storage;
  DeletedPackagesNotifier(this._storage) : super([]) {
    _load();
  }

  void _load() {
    state = _storage.getDeletedPackages();
  }

  Future<void> restore(String id) async {
    await _storage.restoreFromRecycleBin(id);
    _load();
  }

  Future<void> permanentlyDelete(String id) async {
    await _storage.permanentlyDelete(id);
    _load();
  }

  Future<void> clearAll() async {
    await _storage.clearRecycleBin();
    _load();
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
