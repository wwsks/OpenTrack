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
