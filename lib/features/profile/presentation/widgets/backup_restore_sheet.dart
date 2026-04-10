import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:smooth_sheets/smooth_sheets.dart';
import '../../../../../core/services/backup_restore_service.dart';

class BackupRestoreSheet extends StatelessWidget {
  const BackupRestoreSheet({super.key, required this.isBackup});

  final bool isBackup;

  static Future<void> showLocal(BuildContext context, {required bool isBackup}) async {
    await showModalSheet(
      context: context,
      barrierColor: Colors.black54,
      builder: (_) => BackupRestoreSheet(isBackup: isBackup),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final title = isBackup ? 'profile.backup_title'.tr() : 'profile.restore_title'.tr();
    final actionName = isBackup ? 'profile.backup'.tr() : 'profile.restore'.tr();
    final actionIcon = isBackup ? Icons.cloud_upload_rounded : Icons.cloud_download_rounded;
    final desc = isBackup ? 'Securely save your data.' : 'Recover your previous data.';

    return Sheet(
      initialOffset: const SheetOffset(1),
      snapGrid: const SheetSnapGrid.stepless(
        minOffset: SheetOffset(0.4),
      ),
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
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: Text(
                  desc,
                  style: TextStyle(fontSize: 14, color: cs.onSurface.withValues(alpha: 0.6)),
                ),
              ),
              const SizedBox(height: 16),
              
              _SheetOption(
                icon: actionIcon,
                title: '$actionName with Google Drive',
                subtitle: 'Sync securely with your Google cloud storage',
                color: const Color(0xFF4285F4),
                onTap: () async {
                  Navigator.pop(context);
                  if (isBackup) {
                    await BackupRestoreService.backupToGoogleDrive(context);
                  } else {
                    await BackupRestoreService.restoreFromGoogleDrive(context);
                  }
                },
              ),
              const SizedBox(height: 12),
              _SheetOption(
                icon: Icons.save_rounded,
                title: '$actionName Local File',
                subtitle: 'Use the device local file system',
                color: const Color(0xFF00C48C),
                onTap: () {
                  Navigator.pop(context);
                  if (isBackup) {
                    BackupRestoreService.backupDatabase(context);
                  } else {
                    BackupRestoreService.restoreDatabase(context);
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
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

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
                      Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
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
                  Icons.arrow_forward_ios_rounded,
                  color: cs.onSurface.withValues(alpha: 0.3),
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
