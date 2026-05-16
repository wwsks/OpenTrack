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

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final completedIds = prefs.getStringList('completedIds') ?? [];
      final hideCompleted = prefs.getBool('hide_completed_pickups') ?? false;

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
              const PopupMenuItem(
                value: 'taobao',
                child: Row(
                  children: [
                    Icon(Icons.shopping_bag_outlined, size: 20),
                    SizedBox(width: 8),
                    Text('淘宝身份码'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'pdd',
                child: Row(
                  children: [
                    Icon(Icons.local_grocery_store_outlined, size: 20),
                    SizedBox(width: 8),
                    Text('拼多多身份码'),
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
            const Icon(Icons.sms_failed_outlined, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('需要短信权限才能读取取件码',
                style: TextStyle(color: Colors.grey, fontSize: 16)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => openAppSettings(),
              child: const Text('去设置开启权限'),
            ),
          ],
        ),
      );
    }

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
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
            ElevatedButton(
              onPressed: _loadData,
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }

    if (_parcels.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadData,
        child: ListView(
          children: const [
            SizedBox(height: 200),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.inbox_outlined, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('暂无取件码', style: TextStyle(color: Colors.grey, fontSize: 16)),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _parcels.length,
        itemBuilder: (context, index) {
          final parcel = _parcels[index];
          return _ParcelCard(
            parcel: parcel,
            onToggle: _toggleCompleted,
          );
        },
      ),
    );
  }

  void _onStatsSelected(String value) {
    switch (value) {
      case 'success':
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => _SmsListScreen(title: '解析成功', smsList: _successful.map((s) => s.sms).toList(), isFailed: false)));
        break;
      case 'failed':
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => _SmsListScreen(title: '解析失败', smsList: _failed, isFailed: true, parser: _parser, onRuleAdded: _loadData)));
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
    final firstSms = parcel.smsDataList.isNotEmpty ? parcel.smsDataList.first.sms.body : '';
    final parser = SmsParser();
    final company = parser.extractCompany(firstSms);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  parcel.num > 0 ? Icons.location_on : Icons.drafts_outlined,
                  color: parcel.num > 0 ? Colors.blue : Colors.grey,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        parcel.address,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      if (company.isNotEmpty)
                        Text(company,
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                    ],
                  ),
                ),
                if (parcel.num > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.orange,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${parcel.num}',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
              ],
            ),
            const Divider(height: 16),
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

class _PickupCodeItem extends StatelessWidget {
  final SmsData smsData;
  final VoidCallback onToggle;

  const _PickupCodeItem({required this.smsData, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final time = DateTime.fromMillisecondsSinceEpoch(smsData.sms.timestamp);
    final now = DateTime.now();
    String timeStr;
    if (time.year == now.year && time.month == now.month && time.day == now.day) {
      timeStr = '今天 ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    } else {
      timeStr = '${time.month.toString().padLeft(2, '0')}-${time.day.toString().padLeft(2, '0')} '
          '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    }

    return InkWell(
      onTap: onToggle,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Icon(
              smsData.isCompleted ? Icons.check_circle : Icons.radio_button_unchecked,
              size: 22,
              color: smsData.isCompleted ? Colors.green : Colors.orange,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    SmsUtil.formatPickupCode(smsData.code),
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: smsData.isCompleted ? Colors.grey : null,
                      decoration: smsData.isCompleted ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  Text(timeStr,
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                ],
              ),
            ),
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
          ? const Center(child: Text('暂无数据', style: TextStyle(color: Colors.grey)))
          : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: smsList.length,
              itemBuilder: (context, index) {
                final sms = smsList[index];
                final time = DateTime.fromMillisecondsSinceEpoch(sms.timestamp);
                final timeStr =
                    '${time.month.toString().padLeft(2, '0')}-${time.day.toString().padLeft(2, '0')} '
                    '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
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
                              child: const Icon(Icons.copy, size: 16, color: Colors.grey),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
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
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
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
                          child: const Icon(Icons.copy, size: 14, color: Colors.grey),
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
                  border: OutlineInputBorder(),
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
                  border: OutlineInputBorder(),
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

              // 添加码规则
              final codeRule = _generateCodeRule(sms.body, code);
              final codePatterns = prefs.getStringList('custom_code_patterns')?.toSet() ?? {};
              codePatterns.add(codeRule);
              await prefs.setStringList('custom_code_patterns', codePatterns.toList());

              // 添加地址规则（如果填了）
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
