import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/parcel_data.dart';
import '../../models/sms_data.dart';
import '../../models/sms_model.dart';
import '../../utils/sms_parser.dart';
import '../../utils/sms_processor.dart';
import '../../utils/sms_util.dart';
import '../../utils/company_logo.dart';
import '../../animations/animations.dart';

class PickupScreen extends StatefulWidget {
  const PickupScreen({super.key});

  @override
  State<PickupScreen> createState() => _PickupScreenState();
}

class _PickupScreenState extends State<PickupScreen> {
  List<ParcelData> _parcels = [];
  List<SmsData> _successful = [];
  List<SmsModel> _failed = [];
  bool _isLoading = true;
  bool _hasPermission = false;
  String? _loadError;
  final SmsParser _parser = SmsParser();

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final status = await Permission.sms.status;
      if (status.isGranted) {
        setState(() => _hasPermission = true);
        await _loadData();
        _checkXiaomiPermission();
      } else {
        setState(() {
          _hasPermission = false;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _loadError = '初始化失败: $e';
      });
    }
  }

  Future<void> _checkXiaomiPermission() async {
    final prefs = await SharedPreferences.getInstance();
    final hideXiaomiTip = prefs.getBool('hide_xiaomi_sms_tip') ?? false;
    if (hideXiaomiTip) return;

    final brand = await _getDeviceBrand();
    if (brand.toLowerCase().contains('xiaomi') || brand.toLowerCase().contains('redmi')) {
      if (mounted) {
        _showXiaomiPermissionDialog();
      }
    }
  }

  Future<String> _getDeviceBrand() async {
    try {
      const platform = MethodChannel('com.opentrack/device');
      final brand = await platform.invokeMethod<String>('getBrand') ?? '';
      return brand;
    } catch (e) {
      return '';
    }
  }

  void _showXiaomiPermissionDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('小米手机权限提示'),
        content: const Text(
          '小米手机需要额外开启"通知类短信"权限才能读取取件码短信。\n\n'
          '请在系统设置中找到本应用，开启"通知类短信"权限。',
        ),
        actions: [
          TextButton(
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool('hide_xiaomi_sms_tip', true);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('不再显示'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('稍后设置'),
          ),
        ],
      ),
    );
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final completedIds = prefs.getStringList('completedIds') ?? [];
      final hideCompleted = prefs.getBool('hide_completed_pickups') ?? true;

      _parser.clearAllCustomPatterns();
      final result = await SmsProcessor.loadAndProcess(
        parser: _parser,
        completedIds: completedIds,
      );

      List<ParcelData> parcels = result.parcels;
      if (hideCompleted) {
        parcels = parcels.map((parcel) {
          final filtered = parcel.smsDataList.where((s) => !s.isCompleted).toList();
          final uncompletedNum = filtered.fold(0, (sum, s) => sum + s.code.split(', ').length);
          return ParcelData(address: parcel.address, smsDataList: filtered, num: uncompletedNum);
        }).where((p) => p.smsDataList.isNotEmpty).toList();
      }

      if (mounted) {
        setState(() {
          _parcels = parcels;
          _successful = result.successful;
          _failed = result.failed;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _loadError = '读取短信失败: $e';
        });
      }
    }
  }

  Future<void> _toggleCompleted(SmsData smsData) async {
    HapticFeedback.lightImpact();
    final prefs = await SharedPreferences.getInstance();
    final set = prefs.getStringList('completedIds')?.toSet() ?? {};
    final key = smsData.id;

    if (set.contains(key)) {
      set.remove(key);
    } else {
      set.add(key);
    }
    await prefs.setStringList('completedIds', set.toList());
    await _loadData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('取件码'),
        actions: [
          if (!_isLoading && _hasPermission)
            PopupMenuButton<String>(
              icon: const Icon(Icons.analytics_outlined),
              tooltip: '统计',
              onSelected: _onStatsSelected,
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'success',
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle, color: Colors.green, size: 20),
                      const SizedBox(width: 8),
                      Text('解析成功 (${_successful.length})'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'failed',
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red, size: 20),
                      const SizedBox(width: 8),
                      Text('解析失败 (${_failed.length})'),
                    ],
                  ),
                ),
              ],
            ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.qr_code),
            tooltip: '身份码',
            onSelected: _onMenuSelected,
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'taobao',
                child: Row(
                  children: [
                    Image.asset('assets/logos/taobao.png', width: 20, height: 20, fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Icon(Icons.shopping_bag_outlined, size: 20)),
                    const SizedBox(width: 8),
                    const Text('淘宝身份码'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'pdd',
                child: Row(
                  children: [
                    Image.asset('assets/logos/pinduoduo.png', width: 20, height: 20, fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Icon(Icons.local_grocery_store_outlined, size: 20)),
                    const SizedBox(width: 8),
                    const Text('拼多多身份码'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (!_hasPermission) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.sms_failed_outlined, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text('需要短信权限才能读取取件码',
                style: TextStyle(color: Colors.grey.shade400, fontSize: 16)),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => openAppSettings(),
              icon: const Icon(Icons.settings),
              label: const Text('去设置开启权限'),
            ),
          ],
        ),
      );
    }

    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
            const SizedBox(height: 16),
            Text('正在读取短信...',
                style: TextStyle(color: Colors.grey.shade400, fontSize: 14)),
          ],
        ),
      );
    }

    if (_loadError != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(_loadError!, style: const TextStyle(color: Colors.red, fontSize: 14)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh),
              label: const Text('重试'),
            ),
          ],
        ),
      );
    }

    if (_parcels.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadData,
        child: ListView(
          children: [
            const SizedBox(height: 200),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.inbox_outlined, size: 64, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  Text('暂无取件码', style: TextStyle(color: Colors.grey.shade400, fontSize: 16)),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      displacement: 40,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _parcels.length,
        itemBuilder: (context, index) {
          final parcel = _parcels[index];
          return StaggeredListAnimation(
            index: index,
            delay: const Duration(milliseconds: 50),
            child: _ParcelCard(
              parcel: parcel,
              onToggle: _toggleCompleted,
            ),
          );
        },
      ),
    );
  }

  void _onStatsSelected(String value) {
    switch (value) {
      case 'success':
        Navigator.push(context,
            SlideFadeRoute(page: _SmsListScreen(title: '解析成功', smsList: _successful.map((s) => s.sms).toList(), isFailed: false)));
        break;
      case 'failed':
        Navigator.push(context,
            SlideFadeRoute(page: _SmsListScreen(title: '解析失败', smsList: _failed, isFailed: true, parser: _parser, onRuleAdded: _loadData)));
        break;
    }
  }

  void _onMenuSelected(String value) async {
    bool success = false;
    switch (value) {
      case 'taobao':
        success = await _openTaobaoIdentityCode();
        if (!success && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('无法打开淘宝，请确认已安装淘宝App')),
          );
        }
        break;
      case 'pdd':
        success = await _openPddIdentityCode();
        if (!success && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('无法打开拼多多，请确认已安装拼多多App')),
          );
        }
        break;
    }
  }

  Future<bool> _openTaobaoIdentityCode() async {
    const lastmile =
        'https://pages-fast.m.taobao.com/wow/z/uniapp/1100333/last-mile-fe/m-end-school-tab/home';
    final tbopenUrl =
        'tbopen://m.taobao.com/tbopen/index.html?h5Url=${Uri.encodeComponent(lastmile)}';

    for (final url in [tbopenUrl, lastmile, 'taobao://']) {
      try {
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          return true;
        }
      } catch (_) {}
    }
    return false;
  }

  Future<bool> _openPddIdentityCode() async {
    final schemes = [
      'pinduoduo://com.xunmeng.pinduoduo/mdkd/package',
      'pinduoduo://com.xunmeng.pinduoduo/',
      'pinduoduo://',
      'market://details?id=com.xunmeng.pinduoduo',
    ];

    for (final scheme in schemes) {
      try {
        final uri = Uri.parse(scheme);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          return true;
        }
      } catch (_) {}
    }
    return false;
  }
}

class _ParcelCard extends StatelessWidget {
  final ParcelData parcel;
  final void Function(SmsData) onToggle;

  const _ParcelCard({required this.parcel, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Icon(
                    parcel.num > 0 ? Icons.location_on : Icons.drafts_outlined,
                    key: ValueKey(parcel.num > 0),
                    color: parcel.num > 0 ? Colors.blue : Colors.grey,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    parcel.address,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                ),
                if (parcel.num > 0)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.orange,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${parcel.num}',
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
              ],
            ),
            const Divider(height: 20),
            ...parcel.smsDataList.map((smsData) => _PickupCodeItem(
                  smsData: smsData,
                  onToggle: () => onToggle(smsData),
                )),
          ],
        ),
      ),
    );
  }
}

class _PickupCodeItem extends StatefulWidget {
  final SmsData smsData;
  final VoidCallback onToggle;

  const _PickupCodeItem({required this.smsData, required this.onToggle});

  @override
  State<_PickupCodeItem> createState() => _PickupCodeItemState();
}

class _PickupCodeItemState extends State<_PickupCodeItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _checkController;
  late Animation<double> _checkScaleAnimation;

  @override
  void initState() {
    super.initState();
    _checkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _checkScaleAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(parent: _checkController, curve: Curves.easeOutBack),
    );
  }

  @override
  void dispose() {
    _checkController.dispose();
    super.dispose();
  }

  String _getCompany() {
    final parser = SmsParser();
    return parser.extractCompany(widget.smsData.sms.body);
  }

  @override
  Widget build(BuildContext context) {
    final time = DateTime.fromMillisecondsSinceEpoch(widget.smsData.sms.timestamp);
    final now = DateTime.now();
    String timeStr;
    if (time.year == now.year && time.month == now.month && time.day == now.day) {
      timeStr = '今天 ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    } else {
      timeStr = '${time.month.toString().padLeft(2, '0')}-${time.day.toString().padLeft(2, '0')} '
          '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    }

    final company = _getCompany();

    return InkWell(
      onTap: () {
        _checkController.forward(from: 0).then((_) {
          _checkController.reverse();
        });
        widget.onToggle();
      },
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            AnimatedBuilder(
              animation: _checkScaleAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _checkScaleAnimation.value,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    transitionBuilder: (child, animation) {
                      return ScaleTransition(scale: animation, child: child);
                    },
                    child: Icon(
                      widget.smsData.isCompleted
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      key: ValueKey(widget.smsData.isCompleted),
                      size: 24,
                      color: widget.smsData.isCompleted
                          ? Colors.green
                          : Colors.orange,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 300),
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: widget.smsData.isCompleted
                              ? Colors.grey
                              : null,
                          decoration: widget.smsData.isCompleted
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                        child: Text(SmsUtil.formatPickupCode(widget.smsData.code)),
                      ),
                      if (company.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Text(company,
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                      ],
                    ],
                  ),
                  Text(timeStr,
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
                ],
              ),
            ),
            if (company.isNotEmpty) ...[
              const SizedBox(width: 8),
              CompanyLogo.buildLogo(company, size: 28),
            ],
          ],
        ),
      ),
    );
  }
}

class _SmsListScreen extends StatelessWidget {
  final String title;
  final List<SmsModel> smsList;
  final bool isFailed;
  final SmsParser? parser;
  final VoidCallback? onRuleAdded;

  const _SmsListScreen({
    required this.title,
    required this.smsList,
    required this.isFailed,
    this.parser,
    this.onRuleAdded,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('$title (${smsList.length})')),
      body: smsList.isEmpty
          ? Center(child: Text('暂无数据', style: TextStyle(color: Colors.grey.shade400)))
          : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: smsList.length,
              itemBuilder: (context, index) {
                final sms = smsList[index];
                final time = DateTime.fromMillisecondsSinceEpoch(sms.timestamp);
                final timeStr =
                    '${time.month.toString().padLeft(2, '0')}-${time.day.toString().padLeft(2, '0')} '
                    '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

                return StaggeredListAnimation(
                  index: index,
                  delay: const Duration(milliseconds: 30),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(timeStr,
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                              const Spacer(),
                              InkWell(
                                onTap: () {
                                  Clipboard.setData(ClipboardData(text: sms.body));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('已复制短信内容')),
                                  );
                                },
                                borderRadius: BorderRadius.circular(8),
                                child: Padding(
                                  padding: const EdgeInsets.all(4),
                                  child: Icon(Icons.copy, size: 16, color: Colors.grey.shade400),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          SelectableText(sms.body, style: const TextStyle(fontSize: 13)),
                          if (isFailed)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: TextButton.icon(
                                  icon: const Icon(Icons.add, size: 16),
                                  label: const Text('添加规则'),
                                  onPressed: () => _showAddRuleDialog(context, sms),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }

  void _showAddRuleDialog(BuildContext context, SmsModel sms) {
    final codeController = TextEditingController();
    final addressController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('添加解析规则'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text('短信内容', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        const Spacer(),
                        InkWell(
                          onTap: () {
                            Clipboard.setData(ClipboardData(text: sms.body));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('已复制')),
                            );
                          },
                          borderRadius: BorderRadius.circular(4),
                          child: const Padding(
                            padding: EdgeInsets.all(4),
                            child: Icon(Icons.copy, size: 14, color: Colors.grey),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    SelectableText(sms.body, style: const TextStyle(fontSize: 12)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text('取件码（从短信中复制）：'),
              const SizedBox(height: 4),
              TextField(
                controller: codeController,
                decoration: const InputDecoration(
                  hintText: '例如：3-2-5031',
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),
              const Text('驿站地址（选填，从短信中复制）：'),
              const SizedBox(height: 4),
              TextField(
                controller: addressController,
                decoration: const InputDecoration(
                  hintText: '例如：XX小区菜鸟驿站',
                  isDense: true,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              final code = codeController.text.trim();
              final address = addressController.text.trim();
              if (code.isEmpty) return;

              final prefs = await SharedPreferences.getInstance();

              final codeRule = _generateCodeRule(sms.body, code);
              final codePatterns = prefs.getStringList('custom_code_patterns')?.toSet() ?? {};
              codePatterns.add(codeRule);
              await prefs.setStringList('custom_code_patterns', codePatterns.toList());

              if (address.isNotEmpty) {
                final addressPatterns = prefs.getStringList('custom_address_patterns')?.toSet() ?? {};
                addressPatterns.add(address);
                await prefs.setStringList('custom_address_patterns', addressPatterns.toList());
              }

              if (ctx.mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('规则已添加，下次刷新生效')),
                );
                onRuleAdded?.call();
              }
            },
            child: const Text('添加'),
          ),
        ],
      ),
    );
  }

  String _generateCodeRule(String smsBody, String userCode) {
    final parts = smsBody.split(userCode);
    if (parts.length == 2) {
      return RegExp.escape(parts[0]) + r'([\s\S]{2,})' + RegExp.escape(parts[1]);
    } else {
      return RegExp.escape(smsBody).replaceFirst(
        RegExp.escape(userCode),
        r'([\s\S]{2,})',
      );
    }
  }
}
