import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/tracking_info.dart';
import '../../providers/package_provider.dart';
import '../../providers/settings_provider.dart';
import '../../utils/company_util.dart';
import '../detail/detail_screen.dart';
import '../../models/package.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _trackingController = TextEditingController();
  final _remarkController = TextEditingController();
  final _phoneController = TextEditingController();
  ExpressCompany? _selectedCompany;
  bool _isLoading = false;
  TrackingInfo? _result;
  String? _error;
  List<ExpressCompany> _allCompanies = [];

  @override
  void initState() {
    super.initState();
    _loadCompanies();
  }

  Future<void> _loadCompanies() async {
    _allCompanies = await CompanyUtil.loadCompanies();
  }

  @override
  void dispose() {
    _trackingController.dispose();
    _remarkController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  String _getCompanyName(String code) {
    final match = _allCompanies.where((c) => c.code == code).toList();
    return match.isNotEmpty ? match.first.name : code;
  }

  Future<void> _query() async {
    final trackingNumber = _trackingController.text.trim();
    if (trackingNumber.isEmpty) {
      setState(() => _error = '请输入快递单号');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
      _result = null;
    });

    TrackingInfo? info;
    String? err;

    if (_selectedCompany != null) {
      final (r, e) = await ref
          .read(allPackagesProvider.notifier)
          .manualQueryAndAdd(
            trackingNumber: trackingNumber,
            companyCode: _selectedCompany!.code,
            companyName: _selectedCompany!.name,
            phone: _phoneController.text.trim(),
            remark: _remarkController.text.trim(),
          );
      info = r;
      err = e;
    } else {
      final (r, e) = await ref
          .read(allPackagesProvider.notifier)
          .autoDetectAndAdd(
            trackingNumber: trackingNumber,
            phone: _phoneController.text.trim(),
            remark: _remarkController.text.trim(),
          );
      info = r;
      err = e;
    }

    setState(() {
      _isLoading = false;
      _result = info;
      _error = err;
      if (info != null) {
        final companyName = _getCompanyName(info.companyCode);
        _selectedCompany ??= ExpressCompany(
          name: companyName,
          code: info.companyCode,
          type: '',
        );

        // Auto-save if enabled
        final autoSave = ref.read(autoSaveProvider);
        if (autoSave) {
          _addToMyPackages();
        }
      }
    });
  }

  Future<void> _addToMyPackages() async {
    if (_result == null) return;
    final trackingNumber = _trackingController.text.trim();
    final companyName = _selectedCompany?.name ?? _getCompanyName(_result!.companyCode);

    await ref.read(allPackagesProvider.notifier).addPackage(
          trackingNumber: trackingNumber,
          companyCode: _result!.companyCode,
          companyName: companyName,
          phone: _phoneController.text.trim().isNotEmpty
              ? _phoneController.text.trim()
              : null,
          remark: _remarkController.text.trim().isNotEmpty
              ? _remarkController.text.trim()
              : null,
          trackingInfo: _result,
        );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已添加到我的快递')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final autoSave = ref.watch(autoSaveProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('查快递')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _trackingController,
              decoration: const InputDecoration(
                labelText: '快递单号',
                hintText: '请输入快递单号',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.search),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _remarkController,
              decoration: const InputDecoration(
                labelText: '物品备注（选填）',
                hintText: '如：手机壳、书籍等',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.note_alt_outlined),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _phoneController,
              decoration: const InputDecoration(
                labelText: '手机号（顺丰等需要）',
                hintText: '收/寄件人手机号',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.phone),
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 12),
            _CompanySelector(
              selected: _selectedCompany,
              onSelected: (c) => setState(() => _selectedCompany = c),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _query,
              icon: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.search),
              label: Text(_isLoading ? '查询中...' : '查询'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Card(
                color: Colors.red.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(_error!,
                      style: TextStyle(color: Colors.red.shade700)),
                ),
              ),
            ],
            if (_result != null) ...[
              const SizedBox(height: 16),
              _ResultCard(
                trackingNumber: _trackingController.text.trim(),
                info: _result!,
                companyName:
                    _selectedCompany?.name ?? _getCompanyName(_result!.companyCode),
                onAdd: autoSave ? null : _addToMyPackages,
                onViewDetail: () {
                  final pkg = Package(
                    id: '',
                    trackingNumber: _trackingController.text.trim(),
                    companyCode: _result!.companyCode,
                    companyName:
                        _selectedCompany?.name ?? _getCompanyName(_result!.companyCode),
                    remark: _remarkController.text.trim().isNotEmpty
                        ? _remarkController.text.trim()
                        : null,
                  );
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => DetailScreen(
                              package: pkg,
                              trackingInfo: _result!,
                            )),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CompanySelector extends StatelessWidget {
  final ExpressCompany? selected;
  final ValueChanged<ExpressCompany?> onSelected;

  const _CompanySelector({required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final companies = await CompanyUtil.loadCompanies();
        if (!context.mounted) return;
        final result = await showModalBottomSheet<ExpressCompany>(
          context: context,
          isScrollControlled: true,
          builder: (_) => _CompanyPickerSheet(companies: companies),
        );
        if (result != null) onSelected(result);
      },
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: '快递公司（选填，留空自动识别）',
          border: OutlineInputBorder(),
          prefixIcon: Icon(Icons.local_shipping_outlined),
          suffixIcon: Icon(Icons.arrow_drop_down),
        ),
        child: Text(
          selected?.name ?? '自动识别',
          style: TextStyle(
            color: selected != null ? null : Colors.grey,
          ),
        ),
      ),
    );
  }
}

class _CompanyPickerSheet extends StatefulWidget {
  final List<ExpressCompany> companies;
  const _CompanyPickerSheet({required this.companies});

  @override
  State<_CompanyPickerSheet> createState() => _CompanyPickerSheetState();
}

class _CompanyPickerSheetState extends State<_CompanyPickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final filtered = _query.isEmpty
        ? widget.companies
        : widget.companies
            .where((c) =>
                c.name.toLowerCase().contains(_query.toLowerCase()) ||
                c.code.toLowerCase().contains(_query.toLowerCase()))
            .toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.9,
      expand: false,
      builder: (_, controller) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              autofocus: true,
              decoration: const InputDecoration(
                hintText: '搜索快递公司...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: controller,
              itemCount: filtered.length.clamp(0, 200),
              itemBuilder: (_, i) {
                final c = filtered[i];
                return ListTile(
                  title: Text(c.name),
                  subtitle: Text(c.code),
                  onTap: () => Navigator.pop(context, c),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  final String trackingNumber;
  final TrackingInfo info;
  final String companyName;
  final VoidCallback? onAdd;
  final VoidCallback onViewDetail;

  const _ResultCard({
    required this.trackingNumber,
    required this.info,
    required this.companyName,
    required this.onAdd,
    required this.onViewDetail,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.local_shipping,
                    color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '$companyName - $trackingNumber',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                _StatusBadge(state: info.state),
              ],
            ),
            if (info.data.isNotEmpty) ...[
              const Divider(),
              Text(info.data.first.context),
              const SizedBox(height: 4),
              Text(info.data.first.ftime,
                  style: const TextStyle(color: Colors.grey, fontSize: 12)),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onViewDetail,
                    icon: const Icon(Icons.timeline),
                    label: const Text('查看详情'),
                  ),
                ),
                if (onAdd != null) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: onAdd,
                      icon: const Icon(Icons.add),
                      label: const Text('添加到我的快递'),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String state;
  const _StatusBadge({required this.state});

  @override
  Widget build(BuildContext context) {
    Color color;
    String text;
    switch (state) {
      case '0':
        color = Colors.blue;
        text = '在途';
      case '1':
        color = Colors.orange;
        text = '揽收';
      case '5':
        color = Colors.purple;
        text = '派件';
      case '3':
        color = Colors.green;
        text = '签收';
      case '2':
        color = Colors.red;
        text = '疑难';
      default:
        color = Colors.grey;
        text = '未知';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Text(text, style: TextStyle(color: color, fontSize: 12)),
    );
  }
}
