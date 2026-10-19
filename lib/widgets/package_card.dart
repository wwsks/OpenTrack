import 'package:flutter/material.dart';
import '../models/package.dart';
import '../utils/company_logo.dart';
import '../config/theme.dart';
import '../animations/pressable_card.dart';

/// 首页快递卡片（设计简报「各页面视觉统一 · 首页」）：
/// logo 统一底板 + 公司名 16 w600 + 时间右上角次要色 + 单号 13 w600 + 状态 pill。
/// 卡片内边距 16、圆角/阴影走 Card 主题，长公司名/长单号/长轨迹均截断防 overflow。
class PackageCard extends StatelessWidget {
  final Package package;
  final VoidCallback? onTap;

  const PackageCard({
    super.key,
    required this.package,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return PressableCard(
      onTap: onTap,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacePage),
          child: Row(
            children: [
              _AnimatedStatusLogo(
                companyName: package.companyName,
                status: package.status,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            package.companyName,
                            style: TextStyle(
                              color: AppTheme.textPrimary(context),
                              fontWeight: FontWeight.w600,
                              fontSize: AppTheme.fontCardTitle,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: AppTheme.spaceRow),
                        // 更新时间固定右上角，次要色辅助文字
                        Text(
                          _formatTime(package.lastTime),
                          style: TextStyle(
                            color: AppTheme.textSecondary(context),
                            fontSize: AppTheme.fontCaption,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    // 单号用 w600 突出（数字/单号约定），超长截断
                    Text(
                      package.trackingNumber,
                      style: TextStyle(
                        color: AppTheme.textPrimary(context),
                        fontWeight: FontWeight.w600,
                        fontSize: AppTheme.fontSecondary,
                        letterSpacing: 0.3,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (package.remark != null &&
                        package.remark!.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        package.remark!,
                        style: TextStyle(
                          color: AppTheme.textSecondary(context),
                          fontSize: AppTheme.fontCaption,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (package.lastContext.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        package.lastContext,
                        style: TextStyle(
                          color: AppTheme.textPrimary(context),
                          fontSize: AppTheme.fontSecondary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: AppTheme.spaceRow),
                    _StatusPill(status: package.status),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
      return '今天 ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
    return '${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

/// 状态 pill：12% 状态色底 + 状态色字 12 w600（全局规范，映射沿用 statusColor/statusText）
class _StatusPill extends StatelessWidget {
  final String status;
  const _StatusPill({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = AppTheme.statusColor(status);
    return Container(
      padding: AppTheme.statusPillPadding,
      decoration: AppTheme.statusPillDecoration(color),
      child: Text(
        AppTheme.statusText(status),
        style: AppTheme.statusPillTextStyle(color),
      ),
    );
  }
}

class _AnimatedStatusLogo extends StatefulWidget {
  final String companyName;
  final String status;
  const _AnimatedStatusLogo({required this.companyName, required this.status});

  @override
  State<_AnimatedStatusLogo> createState() => _AnimatedStatusLogoState();
}

class _AnimatedStatusLogoState extends State<_AnimatedStatusLogo>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    _pulseAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    // Pulse animation for in-transit packages
    if (widget.status == '0' || widget.status == '5') {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(_AnimatedStatusLogo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.status != oldWidget.status) {
      if (widget.status == '0' || widget.status == '5') {
        _controller.repeat(reverse: true);
      } else {
        _controller.stop();
        _controller.value = 0;
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = AppTheme.statusColor(widget.status);

    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        final pulseValue = _pulseAnimation.value;
        final bgOpacity = 0.08 + (pulseValue * 0.06);

        return Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: bgOpacity),
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            border: Border.all(
              color: statusColor.withValues(alpha: 0.15 + (pulseValue * 0.1)),
              width: AppTheme.hairline,
            ),
          ),
          child: CompanyLogo.buildLogo(widget.companyName, size: 28),
        );
      },
    );
  }
}
