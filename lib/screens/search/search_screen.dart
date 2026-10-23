import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/theme.dart';
import '../../models/tracking_info.dart';
import '../../providers/package_provider.dart';
import '../../providers/settings_provider.dart';
import '../../utils/company_logo.dart';
import '../../utils/company_util.dart';
import '../detail/detail_screen.dart';
import '../../models/package.dart';
import '../../animations/animations.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _trackingController = TextEditingController();
  final _remarkController = TextEditingController();
  final _phoneController = TextEditingController();
  final _batchController = TextEditingController();
  ExpressCompany? _selectedCompany;
  bool _isLoading = false;
  TrackingInfo? _result;
  String? _error;
  List<ExpressCompany> _allCompanies = [];

  bool _isBatchMode = false;
  bool _isBatchLoading = false;
  List<_BatchResult> _batchResults = [];
  int _batchProgress = 0;
  int _batchTotal = 0;

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
    _batchController.dispose();
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

        final autoSave = ref.read(autoSaveProvider);
        if (autoSave) {
          _addToMyPackages();
        }
      }
    });
  }

  Future<void> _batchQuery() async {
    final text = _batchController.text.trim();
    if (text.isEmpty) {
      setState(() => _error = '请输入快递单号，每行一个');
      return;
    }

    final numbers = text
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    if (numbers.isEmpty) {
      setState(() => _error = '请输入快递单号，每行一个');
      return;
    }

    setState(() {
      _isBatchLoading = true;
      _error = null;
      _batchResults = [];
      _batchProgress = 0;
      _batchTotal = numbers.length;
    });

    for (final number in numbers) {
      if (!mounted) break;
      final (info, err) = await ref
          .read(allPackagesProvider.notifier)
          .autoDetectAndAdd(trackingNumber: number);

      setState(() {
        _batchProgress++;
        _batchResults.add(_BatchResult(
          trackingNumber: number,
          info: info,
          error: err,
        ));
      });

      if (_batchProgress < _batchTotal) {
        await Future.delayed(const Duration(seconds: 2));
      }
    }

    if (mounted) {
      setState(() => _isBatchLoading = false);

      final autoSave = ref.read(autoSaveProvider);
      if (autoSave) {
        _addAllBatchToPackages();
      }
    }
  }

  Future<void> _addAllBatchToPackages() async {
    int added = 0;
    int skipped = 0;
    for (final r in _batchResults) {
      if (r.info == null) continue;
      final error = await ref.read(allPackagesProvider.notifier).addPackage(
            trackingNumber: r.trackingNumber,
            companyCode: r.info!.companyCode,
            companyName: _getCompanyName(r.info!.companyCode),
            trackingInfo: r.info,
          );
      if (error != null) {
        skipped++;
      } else {
        added++;
      }
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已添加 $added 个快递${skipped > 0 ? '，跳过 $skipped 个重复' : ''}')),
      );
    }
  }

  Future<void> _addToMyPackages() async {
    if (_result == null) return;
    final trackingNumber = _trackingController.text.trim();
    final companyName = _selectedCompany?.name ?? _getCompanyName(_result!.companyCode);

    final error = await ref.read(allPackagesProvider.notifier).addPackage(
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
      if (error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(error), backgroundColor: AppTheme.accentOrange),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已添加到我的快递')),
        );
      }
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
            // Mode switch with animation
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              child: SegmentedButton<bool>(
                // 选中态不填充整块按钮：仅文字/图标变主题色并加粗，无勾选角标
                showSelectedIcon: false,
                style: ButtonStyle(
                  backgroundColor: const WidgetStatePropertyAll(Colors.transparent),
                  foregroundColor: WidgetStateProperty.resolveWith(
                    (states) => states.contains(WidgetState.selected)
                        ? (Theme.of(context).brightness == Brightness.dark
                            ? AppTheme.primaryDark
                            : AppTheme.primaryBlue)
                        : (Theme.of(context).brightness == Brightness.dark
                            ? AppTheme.darkTextSecondary
                            : AppTheme.lightTextSecondary),
                  ),
                  textStyle: WidgetStateProperty.resolveWith(
                    (states) => TextStyle(
                      fontSize: 14,
                      fontWeight: states.contains(WidgetState.selected)
                          ? FontWeight.w700
                          : FontWeight.w500,
                    ),
                  ),
                  side: WidgetStatePropertyAll(BorderSide(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? AppTheme.darkDivider
                        : AppTheme.lightDivider,
                    width: AppTheme.hairline,
                  )),
                  shape: const WidgetStatePropertyAll(
                    RoundedRectangleBorder(
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                    ),
                  ),
                ),
                segments: const [
                  ButtonSegment(value: false, label: Text('单个查询'), icon: Icon(Icons.search)),
                  ButtonSegment(value: true, label: Text('批量查询'), icon: Icon(Icons.playlist_add)),
                ],
                selected: {_isBatchMode},
                onSelectionChanged: (v) => setState(() {
                  _isBatchMode = v.first;
                  _error = null;
                  _result = null;
                  _batchResults = [];
                }),
              ),
            ),
            const SizedBox(height: 20),

            // Animated mode switching
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (child, animation) {
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0.05, 0),
                      end: Offset.zero,
                    ).animate(CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOutCubic,
                    )),
                    child: child,
                  ),
                );
              },
              child: _isBatchMode ? _buildBatchMode(autoSave) : _buildSingleMode(autoSave),
            ),

            if (_error != null) ...[
              const SizedBox(height: 16),
              StaggeredListAnimation(
                index: 0,
                delay: Duration.zero,
                child: Container(
                  padding: const EdgeInsets.all(AppTheme.spacePage),
                  decoration: BoxDecoration(
                    color: AppTheme.accentRed.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline,
                          color: AppTheme.accentRed, size: 20),
                      const SizedBox(width: AppTheme.spaceIconText),
                      Expanded(
                        child: Text(_error!,
                            style: const TextStyle(
                                color: AppTheme.accentRed,
                                fontSize: AppTheme.fontBody)),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            if (!_isBatchMode && _result != null) ...[
              const SizedBox(height: 16),
              StaggeredListAnimation(
                index: 0,
                delay: Duration.zero,
                child: _ResultCard(
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
                      SlideFadeRoute(page: DetailScreen(
                        package: pkg,
                        trackingInfo: _result!,
                      )),
                    );
                  },
                ),
              ),
            ],

            if (_isBatchMode && _batchResults.isNotEmpty) ...[
              const SizedBox(height: 16),
              StaggeredListAnimation(
                index: 0,
                delay: Duration.zero,
                child: _BatchResultList(
                  results: _batchResults,
                  getCompanyName: _getCompanyName,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSingleMode(bool autoSave) {
    return Column(
      key: const ValueKey('single'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _trackingController,
          decoration: const InputDecoration(
            labelText: '快递单号',
            hintText: '请输入快递单号',
            prefixIcon: Icon(Icons.search),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _remarkController,
          decoration: const InputDecoration(
            labelText: '物品备注（选填）',
            hintText: '如：手机壳、书籍等',
            prefixIcon: Icon(Icons.note_alt_outlined),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _phoneController,
          decoration: const InputDecoration(
            labelText: '手机号（顺丰等需要）',
            hintText: '收/寄件人手机号',
            prefixIcon: Icon(Icons.phone),
          ),
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 12),
        _CompanySelector(
          selected: _selectedCompany,
          onSelected: (c) => setState(() => _selectedCompany = c),
        ),
        const SizedBox(height: 20),
        AppTheme.primaryButton(
          label: _isLoading ? '查询中...' : '查询',
          icon: Icons.search,
          busy: _isLoading,
          onTap: _query,
        ),
      ],
    );
  }

  Widget _buildBatchMode(bool autoSave) {
    return Column(
      key: const ValueKey('batch'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _batchController,
          maxLines: 6,
          decoration: const InputDecoration(
            labelText: '快递单号',
            hintText: '每行输入一个快递单号\n例如：\nYT1234567890\nSF1234567890',
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: 20),
        AppTheme.primaryButton(
          label: _isBatchLoading
              ? '查询中 ($_batchProgress/$_batchTotal)'
              : '批量查询',
          icon: Icons.playlist_add,
          busy: _isBatchLoading,
          onTap: _batchQuery,
        ),
        if (!autoSave && _batchResults.isNotEmpty && !_isBatchLoading) ...[
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _addAllBatchToPackages,
            icon: const Icon(Icons.add_circle_outline),
            label: const Text('全部添加到我的快递'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ],
      ],
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
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: '快递公司（选填，留空自动识别）',
          prefixIcon: Icon(Icons.local_shipping_outlined),
          suffixIcon: Icon(Icons.arrow_drop_down),
        ),
        child: selected == null
            ? Text(
                '自动识别',
                style: TextStyle(
                  color: AppTheme.textSecondary(context),
                  fontSize: AppTheme.fontBody,
                ),
              )
            // 已选公司渲染成统一 pill（12% 强调色底 + 强调色字 12 w600）
            : Container(
                padding: AppTheme.statusPillPadding,
                decoration:
                    AppTheme.statusPillDecoration(AppTheme.accent(context)),
                child: Text(
                  selected!.name,
                  style: AppTheme.statusPillTextStyle(AppTheme.accent(context)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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
        padding: const EdgeInsets.all(AppTheme.spacePage),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CompanyLogo.buildLogo(companyName, size: 32),
                const SizedBox(width: AppTheme.spaceIconText),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        companyName,
                        style: TextStyle(
                          color: AppTheme.textPrimary(context),
                          fontWeight: FontWeight.w600,
                          fontSize: AppTheme.fontCardTitle,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        trackingNumber,
                        style: TextStyle(
                          color: AppTheme.textPrimary(context),
                          fontWeight: FontWeight.w600,
                          fontSize: AppTheme.fontSecondary,
                          letterSpacing: 0.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppTheme.spaceRow),
                _StatusBadge(state: info.state),
              ],
            ),
            if (info.data.isNotEmpty) ...[
              const Divider(height: 24),
              Text(
                info.data.first.context,
                style: TextStyle(
                    fontSize: AppTheme.fontBody,
                    color: AppTheme.textPrimary(context)),
              ),
              const SizedBox(height: 4),
              Text(
                info.data.first.ftime,
                style: TextStyle(
                    color: AppTheme.textSecondary(context),
                    fontSize: AppTheme.fontCaption),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onViewDetail,
                    icon: const Icon(Icons.timeline, size: 18),
                    label: const Text('查看详情'),
                  ),
                ),
                if (onAdd != null) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: onAdd,
                      icon: const Icon(Icons.add, size: 18),
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

class _BatchResult {
  final String trackingNumber;
  final TrackingInfo? info;
  final String? error;

  _BatchResult({required this.trackingNumber, this.info, this.error});
}

class _BatchResultList extends StatelessWidget {
  final List<_BatchResult> results;
  final String Function(String) getCompanyName;

  const _BatchResultList({required this.results, required this.getCompanyName});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacePage),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('查询结果 (${results.where((r) => r.info != null).length}/${results.length} 成功)',
                style: TextStyle(
                    color: AppTheme.textPrimary(context),
                    fontWeight: FontWeight.w600,
                    fontSize: AppTheme.fontBody)),
            const Divider(height: 20),
            ...results.asMap().entries.map((entry) {
              final i = entry.key;
              final r = entry.value;
              return StaggeredListAnimation(
                index: i,
                delay: const Duration(milliseconds: 40),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Icon(
                        r.info != null ? Icons.check_circle : Icons.error_outline,
                        size: 20,
                        color: r.info != null
                            ? AppTheme.accentGreen
                            : AppTheme.accentRed,
                      ),
                      const SizedBox(width: AppTheme.spaceIconText),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(r.trackingNumber,
                                style: TextStyle(
                                    fontSize: AppTheme.fontSecondary,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.textPrimary(context)),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                            if (r.info != null)
                              Text(
                                '${getCompanyName(r.info!.companyCode)} · ${r.info!.data.isNotEmpty ? r.info!.data.first.context : "暂无轨迹"}',
                                style: TextStyle(
                                    fontSize: AppTheme.fontCaption,
                                    color: AppTheme.textSecondary(context)),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              )
                            else
                              Text(r.error ?? '查询失败',
                                  style: const TextStyle(
                                      fontSize: AppTheme.fontCaption,
                                      color: AppTheme.accentRed)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

/// 状态 pill：12% 状态色底 + 状态色字 12 w600（与首页卡片同一套映射与样式）
class _StatusBadge extends StatelessWidget {
  final String state;
  const _StatusBadge({required this.state});

  @override
  Widget build(BuildContext context) {
    final color = AppTheme.statusColor(state);
    return Container(
      padding: AppTheme.statusPillPadding,
      decoration: AppTheme.statusPillDecoration(color),
      child: Text(
        AppTheme.statusText(state),
        style: AppTheme.statusPillTextStyle(color),
      ),
    );
  }
}
