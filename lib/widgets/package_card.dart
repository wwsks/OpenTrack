import 'package:flutter/material.dart';
import '../models/package.dart';
import '../utils/company_logo.dart';
import '../config/theme.dart';

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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              _AnimatedStatusLogo(
                companyName: package.companyName,
                status: package.status,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            package.companyName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        _StatusDot(status: package.status),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      package.trackingNumber,
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 13,
                        letterSpacing: 0.3,
                      ),
                    ),
                    if (package.remark != null &&
                        package.remark!.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        package.remark!,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (package.lastContext.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        package.lastContext,
                        style: const TextStyle(fontSize: 13),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      _formatTime(package.lastTime),
                      style: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 11,
                      ),
                    ),
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
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: statusColor.withValues(alpha: 0.15 + (pulseValue * 0.1)),
              width: 1,
            ),
          ),
          child: CompanyLogo.buildLogo(widget.companyName, size: 28),
        );
      },
    );
  }
}

class _StatusDot extends StatefulWidget {
  final String status;
  const _StatusDot({required this.status});

  @override
  State<_StatusDot> createState() => _StatusDotState();
}

class _StatusDotState extends State<_StatusDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _glowAnimation = Tween<double>(begin: 0.3, end: 0.8).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    if (widget.status == '0' || widget.status == '5') {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(_StatusDot oldWidget) {
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
    final color = AppTheme.statusColor(widget.status);
    final isActive = widget.status == '0' || widget.status == '5';

    if (!isActive) {
      return Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
      );
    }

    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, child) {
        return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: _glowAnimation.value * 0.5),
                blurRadius: 4 + (_glowAnimation.value * 2),
                spreadRadius: _glowAnimation.value,
              ),
            ],
          ),
        );
      },
    );
  }
}
