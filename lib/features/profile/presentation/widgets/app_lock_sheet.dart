import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:animate_do/animate_do.dart';
import 'package:smooth_sheets/smooth_sheets.dart';
import 'package:toastification/toastification.dart';
import '../../../../core/services/app_lock_service.dart';

// ---------------------------------------------------------------------------
// App Lock Sheet — biometric toggle via smooth_sheets
// ---------------------------------------------------------------------------

Future<void> showAppLockSheet(BuildContext context, WidgetRef ref) {
  return Navigator.push(
    context,
    ModalSheetRoute(
      builder: (_) => const AppLockSheet(),
    ),
  );
}

class AppLockSheet extends ConsumerStatefulWidget {
  const AppLockSheet({super.key});

  @override
  ConsumerState<AppLockSheet> createState() => _AppLockSheetState();
}

class _AppLockSheetState extends ConsumerState<AppLockSheet> {
  bool _isEnabled = false;
  bool _loading = true;
  bool _toggling = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final lockService = ref.read(appLockServiceProvider);
    final value = await lockService.isLockEnabled();
    if (!mounted) return;
    setState(() { _isEnabled = value; _loading = false; });
  }

  Future<void> _onToggle(bool value) async {
    if (_toggling) return;
    setState(() => _toggling = true);
    final lockService = ref.read(appLockServiceProvider);

    if (value) {
      final ok = await lockService.authenticate();
      if (!mounted) return;
      if (ok) {
        await lockService.setLockEnabled(true);
        setState(() => _isEnabled = true);
        _showToast('profile.lock_enable_success'.tr(), ToastificationType.success);
      } else {
        _showToast('profile.lock_failed'.tr(), ToastificationType.error);
      }
    } else {
      await lockService.setLockEnabled(false);
      if (!mounted) return;
      setState(() => _isEnabled = false);
      _showToast('profile.lock_disable_success'.tr(), ToastificationType.success);
    }
    setState(() => _toggling = false);
  }

  void _showToast(String msg, ToastificationType type) {
    toastification.show(
      context: context,
      type: type,
      style: ToastificationStyle.flatColored,
      title: Text(msg),
      autoCloseDuration: const Duration(seconds: 3),
      animationBuilder: (context, animation, alignment, child) {
        return FadeTransition(opacity: animation, child: child);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Sheet(
      initialOffset: const SheetOffset(1),
      snapGrid: const SheetSnapGrid.stepless(
        minOffset: SheetOffset(0.4),
      ),
      child: SheetContentScaffold(
        body: Container(
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 12),
                    Center(
                      child: Container(
                        width: 40, height: 4,
                        decoration: BoxDecoration(
                          color: cs.onSurface.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          FadeInDown(
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: _isEnabled
                                          ? [Colors.green, Colors.teal]
                                          : [Colors.grey, Colors.blueGrey],
                                    ),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Icon(
                                    _isEnabled ? Icons.lock_rounded : Icons.lock_open_rounded,
                                    color: Colors.white, size: 22,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Text(
                                  'profile.lock_title'.tr(),
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: cs.onSurface,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 28),
                          FadeInUp(
                            delay: const Duration(milliseconds: 100),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: _isEnabled
                                    ? Colors.green.withValues(alpha: 0.08)
                                    : cs.surfaceContainerLow,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: _isEnabled
                                      ? Colors.green.withValues(alpha: 0.3)
                                      : Colors.transparent,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.fingerprint_rounded,
                                              color: _isEnabled ? Colors.green : cs.onSurface.withValues(alpha: 0.5),
                                              size: 20,
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              'profile.app_lock'.tr(),
                                              style: TextStyle(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 16,
                                                color: cs.onSurface,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          _isEnabled
                                              ? 'profile.lock_enabled'.tr()
                                              : 'profile.lock_disabled'.tr(),
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: _isEnabled ? Colors.green : cs.onSurface.withValues(alpha: 0.5),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  _toggling
                                      ? const SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 2))
                                      : Switch.adaptive(
                                          value: _isEnabled,
                                          onChanged: _onToggle,
                                          activeThumbColor: Colors.green,
                                        ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          FadeInUp(
                            delay: const Duration(milliseconds: 200),
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: cs.primary.withValues(alpha: 0.06),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.info_outline_rounded, size: 18, color: cs.primary),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'profile.lock_bio_note'.tr(),
                                      style: TextStyle(fontSize: 13, color: cs.onSurface.withValues(alpha: 0.6)),
                                    ),
                                  ),
                                ],
                              ),
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
}
