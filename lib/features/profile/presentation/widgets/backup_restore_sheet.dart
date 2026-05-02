import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smooth_sheets/smooth_sheets.dart';
import 'package:go_router/go_router.dart';
import '../../../../../core/config/premium_config.dart';
import '../../../../../core/services/backup_restore_service.dart';
import '../../../../../core/services/subscription_service.dart';
import 'subscription_sheet.dart';

class BackupRestoreSheet extends ConsumerWidget {
  const BackupRestoreSheet({
    super.key,
    required this.isBackup,
    required this.hostContext,
  });

  final bool isBackup;
  final BuildContext hostContext;

  static Future<void> showLocal(
    BuildContext context, {
    required bool isBackup,
  }) async {
    await showModalSheet(
      context: context,
      barrierColor: Colors.black54,
      builder:
          (_) => BackupRestoreSheet(isBackup: isBackup, hostContext: context),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final isPro = ref.watch(isProProvider);
    final isDriveLocked = PremiumConfig.isLocked(
      feature: PremiumFeature.googleDriveBackupRestore,
      isPro: isPro,
    );
    final title =
        isBackup ? 'profile.backup_title'.tr() : 'profile.restore_title'.tr();
    final actionName =
        isBackup ? 'profile.backup'.tr() : 'profile.restore'.tr();
    final actionIcon =
        isBackup ? Icons.cloud_upload_rounded : Icons.cloud_download_rounded;
    final desc =
        isBackup
            ? 'profile.backup_sheet_desc'.tr()
            : 'profile.restore_sheet_desc'.tr();

    return Sheet(
      initialOffset: const SheetOffset(1),
      snapGrid: const SheetSnapGrid.stepless(minOffset: SheetOffset(0.4)),
      child: SheetContentScaffold(
        body: Container(
          decoration: BoxDecoration(
            color: cs.surfaceContainerLow,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: cs.onSurface.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 8,
                ),
                child: Text(
                  desc,
                  style: TextStyle(
                    fontSize: 14,
                    color: cs.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              _SheetOption(
                icon: actionIcon,
                title: 'profile.drive_option_title'.tr(args: [actionName]),
                subtitle: 'profile.drive_option_subtitle'.tr(),
                color: const Color(0xFF4285F4),
                isLocked: isDriveLocked,
                onTap: () async {
                  final navigator = Navigator.of(context);
                  if (isDriveLocked) {
                    navigator.pop();
                    SubscriptionSheet.show(hostContext);
                    return;
                  }

                  final restored =
                      isBackup
                          ? await BackupRestoreService.backupToGoogleDrive(
                            context,
                          )
                          : await BackupRestoreService.restoreFromGoogleDrive(
                            context,
                          );

                  if (!hostContext.mounted) return;
                  navigator.pop();
                  if (!isBackup && restored) {
                    hostContext.go('/splash');
                  }
                },
              ),
              const SizedBox(height: 12),
              _SheetOption(
                icon: Icons.save_rounded,
                title: 'profile.file_option_title'.tr(args: [actionName]),
                subtitle: 'profile.file_option_subtitle'.tr(),
                color: const Color(0xFF00C48C),
                onTap: () async {
                  final navigator = Navigator.of(context);
                  final restored =
                      isBackup
                          ? await BackupRestoreService.backupDatabase(context)
                          : await BackupRestoreService.restoreDatabase(context);

                  if (!hostContext.mounted) return;
                  navigator.pop();
                  if (!isBackup && restored) {
                    hostContext.go('/splash');
                  }
                },
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

class _SheetOption extends StatelessWidget {
  const _SheetOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
    this.isLocked = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
  final bool isLocked;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Material(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          if (isLocked) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.amber.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                'get_started.pro_badge'.tr(),
                                style: const TextStyle(
                                  color: Colors.orange,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  isLocked
                      ? Icons.lock_outline_rounded
                      : Icons.arrow_forward_ios_rounded,
                  color: cs.onSurface.withValues(alpha: 0.3),
                  size: isLocked ? 18 : 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
