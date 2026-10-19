import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/package.dart';
import '../../models/tracking_info.dart';
import '../../providers/llm_provider.dart';
import '../../providers/package_provider.dart';
import '../../providers/settings_provider.dart';
import '../../config/theme.dart';
import '../../animations/animations.dart';
import '../../utils/company_logo.dart';
import '../../utils/llm_prompts.dart';

class DetailScreen extends ConsumerStatefulWidget {
  final Package package;
  final TrackingInfo? trackingInfo;

  const DetailScreen({super.key, required this.package, this.trackingInfo});

  @override
  ConsumerState<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends ConsumerState<DetailScreen> {
  TrackingInfo? _trackingInfo;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _trackingInfo = widget.trackingInfo;
    if (_trackingInfo == null) {
      _fetchTrackingInfo();
    }
  }

  Future<void> _fetchTrackingInfo() async {
    setState(() => _isLoading = true);
    final info = await ref
        .read(allPackagesProvider.notifier)
        .querySingle(widget.package);
    if (mounted) {
      setState(() {
        _trackingInfo = info;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final llmConfigured = ref.watch(llmSettingsProvider).isConfigured;
    return Scaffold(
      appBar: AppBar(
        title: const Text('快递详情'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              HapticFeedback.lightImpact();
              await ref
                  .read(allPackagesProvider.notifier)
                  .refreshSingle(widget.package);
              await _fetchTrackingInfo();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('已刷新')),
                );
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            StaggeredListAnimation(
              index: 0,
              delay: const Duration(milliseconds: 80),
              child: _InfoCard(package: widget.package),
            ),
            const SizedBox(height: 12),
            if (_isLoading)
              StaggeredListAnimation(
                index: 1,
                delay: const Duration(milliseconds: 80),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Center(
                      child: Column(
                        children: [
                          const SizedBox(
                            width: 28,
                            height: 28,
                            child: CircularProgressIndicator(strokeWidth: 2.5),
                          ),
                          const SizedBox(height: 12),
                          Text('正在查询...',
                              style: TextStyle(
                                  color: AppTheme.textSecondary(context),
                                  fontSize: AppTheme.fontBody)),
                        ],
                      ),
                    ),
                  ),
                ),
              )
            else if (_trackingInfo != null)
              StaggeredListAnimation(
                index: 1,
                delay: const Duration(milliseconds: 80),
                child: _TimelineCard(info: _trackingInfo!),
              )
            else
              StaggeredListAnimation(
                index: 1,
                delay: const Duration(milliseconds: 80),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Center(
                      child: Text('暂无轨迹信息',
                          style: TextStyle(
                              color: AppTheme.textSecondary(context))),
                    ),
                  ),
                ),
              ),
            // 预计送达（估算）：有轨迹 && 未签收 && LLM 已配置时才显示
            if (_trackingInfo != null &&
                _trackingInfo!.data.isNotEmpty &&
                !_trackingInfo!.isSigned &&
                llmConfigured) ...[
              const SizedBox(height: 12),
              // 用最新轨迹的缓存键做 Key：刷新轨迹后 key 变化即重建卡片，
              // 重新走缓存判断（命中则直接展示，未命中重新生成）
              KeyedSubtree(
                key: ValueKey(etaCacheKey(
                  _trackingInfo!.data.first.context,
                  _trackingInfo!.data.first.time,
                )),
                child: _EtaCard(
                  info: _trackingInfo!,
                  companyName: widget.package.companyName,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final Package package;
  const _InfoCard({required this.package});

  @override
  Widget build(BuildContext context) {
    final statusColor = AppTheme.statusColor(package.status);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacePage),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // logo 状态底板：与首页卡片同一规格（44x44、圆角 10、状态色轻染）
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    border: Border.all(
                      color: statusColor.withValues(alpha: 0.15),
                      width: AppTheme.hairline,
                    ),
                  ),
                  child: CompanyLogo.buildLogo(package.companyName, size: 28),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        package.companyName,
                        style: TextStyle(
                          color: AppTheme.textPrimary(context),
                          fontWeight: FontWeight.w600,
                          fontSize: AppTheme.fontCardTitle,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: AppTheme.statusPillPadding,
                        decoration: AppTheme.statusPillDecoration(statusColor),
                        child: Text(
                          package.isSigned ? '已签收' : '未签收',
                          style: AppTheme.statusPillTextStyle(statusColor),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            _trackingRow(context),
            if (package.remark != null && package.remark!.isNotEmpty)
              _infoRow(context, '物品备注', package.remark!),
            _infoRow(context, '添加时间', _formatDate(package.addedTime)),
            _infoRow(context, '更新时间', _formatDate(package.lastTime)),
          ],
        ),
      ),
    );
  }

  Widget _trackingRow(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text('快递单号',
                style: TextStyle(
                    color: AppTheme.textSecondary(context),
                    fontSize: AppTheme.fontBody)),
          ),
          Expanded(
            child: Text(package.trackingNumber,
                style: TextStyle(
                    fontSize: AppTheme.fontBody,
                    color: AppTheme.textPrimary(context),
                    letterSpacing: 0.3)),
          ),
          InkWell(
            onTap: () {
              HapticFeedback.lightImpact();
              Clipboard.setData(ClipboardData(text: package.trackingNumber));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('已复制快递单号')),
              );
            },
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Icon(Icons.copy,
                  size: 18, color: AppTheme.textSecondary(context)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text(label,
                style: TextStyle(
                    color: AppTheme.textSecondary(context),
                    fontSize: AppTheme.fontBody)),
          ),
          Expanded(
            child: Text(value,
                style: TextStyle(
                    fontSize: AppTheme.fontBody,
                    color: AppTheme.textPrimary(context))),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

class _TimelineCard extends StatelessWidget {
  final TrackingInfo info;
  const _TimelineCard({required this.info});

  @override
  Widget build(BuildContext context) {
    // 轨迹时间线圆点/连线用状态色，节点文字两级灰阶（最新一级主色 w600，其余次要色）
    final statusColor = AppTheme.statusColor(info.state);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacePage),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('物流轨迹',
                style: TextStyle(
                    fontSize: AppTheme.fontCardTitle,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary(context))),
            const SizedBox(height: 16),
            if (info.data.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('暂无轨迹信息',
                      style: TextStyle(
                          color: AppTheme.textSecondary(context))),
                ),
              )
            else
              ...info.data.asMap().entries.map((entry) {
                final i = entry.key;
                final event = entry.value;
                final isFirst = i == 0;
                final isLast = i == info.data.length - 1;
                return StaggeredListAnimation(
                  index: i,
                  delay: const Duration(milliseconds: 60),
                  slideOffset: const Offset(0.06, 0),
                  child: _TimelineItem(
                    context: event.context,
                    time: event.ftime,
                    isFirst: isFirst,
                    isLast: isLast,
                    statusColor: statusColor,
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

class _TimelineItem extends StatelessWidget {
  final String context;
  final String time;
  final bool isFirst;
  final bool isLast;
  final Color statusColor;

  const _TimelineItem({
    required this.context,
    required this.time,
    required this.isFirst,
    required this.isLast,
    required this.statusColor,
  });

  @override
  Widget build(BuildContext context) {
    final color = isFirst ? statusColor : statusColor.withValues(alpha: 0.45);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 28,
            child: Column(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: isFirst ? 14 : 10,
                  height: isFirst ? 14 : 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color,
                    boxShadow: isFirst
                        ? [
                            BoxShadow(
                              color: color.withValues(alpha: 0.3),
                              blurRadius: 6,
                              spreadRadius: 1,
                            ),
                          ]
                        : null,
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      // 连线延续状态色，压到 20% 透明度保持轻量
                      color: statusColor.withValues(alpha: 0.2),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    this.context,
                    style: TextStyle(
                      fontSize: isFirst
                          ? AppTheme.fontBody
                          : AppTheme.fontSecondary,
                      color: isFirst
                          ? AppTheme.textPrimary(context)
                          : AppTheme.textSecondary(context),
                      fontWeight:
                          isFirst ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(time,
                      style: TextStyle(
                          fontSize: AppTheme.fontCaption,
                          color: AppTheme.textSecondary(context))),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 预计送达（估算）卡片：加载/成功/失败三态，按最新轨迹哈希缓存，失败可点击重试
class _EtaCard extends ConsumerStatefulWidget {
  final TrackingInfo info;
  final String companyName;

  const _EtaCard({required this.info, required this.companyName});

  @override
  ConsumerState<_EtaCard> createState() => _EtaCardState();
}

class _EtaCardState extends ConsumerState<_EtaCard> {
  bool _loading = true;
  EtaEstimate? _estimate;

  @override
  void initState() {
    super.initState();
    _run();
  }

  /// 生成估算：先查缓存（脏数据按未命中），未命中再调 LLM，成功后回写缓存
  Future<void> _run() async {
    final event = widget.info.data.first;
    final key = etaCacheKey(event.context, event.time);
    final storage = ref.read(storageServiceProvider);

    // 读缓存：脏数据（解析异常/结构不符）一律按未命中处理，不让页面崩溃
    var cache = <String, Map<String, String>>{};
    try {
      cache = await storage.getLlmEtaCache();
    } catch (_) {}

    EtaEstimate? estimate;
    final cached = cache[key];
    final cachedEstimate = cached?['estimate'];
    final cachedReason = cached?['reason'];
    if (cachedEstimate != null && cachedReason != null) {
      estimate = EtaEstimate(estimate: cachedEstimate, reason: cachedReason);
    }
    if (!mounted) return;

    // 未命中再调 LLM 生成；任何异常（含 LlmException）都停留在失败态等待重试
    if (estimate == null) {
      try {
        final llm = ref.read(llmServiceProvider);
        if (llm != null) {
          final text = await llm.chat(
            system: kEtaSystemPrompt,
            user: buildEtaPrompt(
              companyName: widget.companyName,
              traceContext: event.context,
              traceTime: event.time,
            ),
            jsonMode: true,
          );
          estimate = tryParseEta(text);
          // 成功后回写缓存；写缓存失败只丢缓存，不影响展示（estimate 已赋值）
          if (estimate != null) {
            cache[key] = {
              'estimate': estimate.estimate,
              'reason': estimate.reason,
            };
            await storage.setLlmEtaCache(cache);
          }
        }
      } catch (_) {}
    }

    if (!mounted) return;
    setState(() {
      _loading = false;
      _estimate = estimate;
    });
  }

  /// 失败后点击重新发起
  void _retry() {
    setState(() {
      _loading = true;
      _estimate = null;
    });
    _run();
  }

  @override
  Widget build(BuildContext context) {
    final textPrimary = AppTheme.textPrimary(context);
    final textSecondary = AppTheme.textSecondary(context);
    final accent = AppTheme.accent(context);

    // ETA 卡：左侧 3px 主色条突出「估算」属性，整体仍与信息卡/轨迹卡同一家族
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: AppTheme.cardDecoration(context),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 3, color: accent),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.spacePage),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('预计送达（估算）',
                        style: TextStyle(
                            fontSize: AppTheme.fontCardTitle,
                            fontWeight: FontWeight.w600,
                            color: textPrimary)),
                    const SizedBox(height: 12),
                    _buildContent(textSecondary, accent),
                    const SizedBox(height: 12),
                    // 这是估算不是承诺：角注常驻，任何状态都保留标注
                    Text('AI 估算，仅供参考',
                        style: TextStyle(
                            fontSize: 11, color: textSecondary)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(Color textSecondary, Color accent) {
    if (_loading) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
                strokeWidth: 2.5, color: accent),
          ),
        ),
      );
    }

    final estimate = _estimate;
    if (estimate == null) {
      return Center(
        child: TextButton.icon(
          onPressed: _retry,
          style: TextButton.styleFrom(foregroundColor: AppTheme.accentRed),
          icon: const Icon(Icons.refresh),
          label: const Text('生成失败，点击重试'),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(estimate.estimate,
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.w600, color: accent)),
        const SizedBox(height: 6),
        Text(estimate.reason,
            style: TextStyle(fontSize: 13, color: textSecondary)),
      ],
    );
  }
}
