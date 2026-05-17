import 'package:flutter/material.dart';
import '../models/package.dart';
import '../utils/company_logo.dart';

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
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              _CompanyLogoOrStatus(companyName: package.companyName, status: package.status),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      package.companyName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      package.trackingNumber,
                      style:
                          const TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                    if (package.remark != null &&
                        package.remark!.isNotEmpty) ...[
                      const SizedBox(height: 2),
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
                      const SizedBox(height: 4),
                      Text(
                        package.lastContext,
                        style: const TextStyle(fontSize: 13),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 2),
                    Text(
                      _formatTime(package.lastTime),
                      style: TextStyle(
                        color: Colors.grey.shade500,
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

class _CompanyLogoOrStatus extends StatelessWidget {
  final String companyName;
  final String status;
  const _CompanyLogoOrStatus({required this.companyName, required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: _statusColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: CompanyLogo.buildLogo(companyName, size: 28),
    );
  }

  Color get _statusColor {
    switch (status) {
      case '0': return Colors.blue;
      case '1': return Colors.orange;
      case '3': return Colors.green;
      case '5': return Colors.purple;
      case '2': return Colors.red;
      default:  return Colors.grey;
    }
  }
}
