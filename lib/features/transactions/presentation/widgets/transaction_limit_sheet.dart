import 'package:flutter/material.dart';

import 'package:easy_localization/easy_localization.dart';

import '../../../../core/config/premium_config.dart';

enum TransactionLimitAction { upgrade, watchAd }

class TransactionLimitSheet extends StatelessWidget {
  const TransactionLimitSheet({super.key});

  static Future<TransactionLimitAction?> show(BuildContext context) {
    return showModalBottomSheet<TransactionLimitAction>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => const TransactionLimitSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: cs.onSurface.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'transaction.free_limit_reached_title'.tr(),
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'transaction.free_limit_reached'.tr(
              args: ['${PremiumConfig.maxFreeTransactions}'],
            ),
            style: TextStyle(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          _ActionTile(
            icon: Icons.ondemand_video_rounded,
            color: const Color(0xFF00C48C),
            title: 'transaction.watch_ad_title'.tr(),
            subtitle: 'transaction.watch_ad_desc'.tr(),
            onTap: () => Navigator.pop(context, TransactionLimitAction.watchAd),
          ),
          const SizedBox(height: 12),
          _ActionTile(
            icon: Icons.workspace_premium_rounded,
            color: const Color(0xFFFF9800),
            title: 'profile.upgrade_premium'.tr(),
            subtitle: 'profile.premium_subtitle'.tr(),
            onTap: () => Navigator.pop(context, TransactionLimitAction.upgrade),
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Material(
      color: cs.surfaceContainerLow,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: cs.onSurface.withValues(alpha: 0.35),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
