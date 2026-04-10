import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:smooth_sheets/smooth_sheets.dart';
import 'package:animate_do/animate_do.dart';
import '../../../../core/services/shared_preferences_service.dart';

// ---------------------------------------------------------------------------
// Edit Profile Sheet — smooth_sheets 0.17.0 API
// ---------------------------------------------------------------------------

Future<dynamic> showEditProfileSheet(BuildContext context) {
  return Navigator.push(
    context,
    ModalSheetRoute(
      builder: (context) => const EditProfileSheet(),
    ),
  );
}

class EditProfileSheet extends ConsumerStatefulWidget {
  const EditProfileSheet({super.key});

  @override
  ConsumerState<EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends ConsumerState<EditProfileSheet> {
  final _ctrl = TextEditingController();
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadName();
  }

  Future<void> _loadName() async {
    final prefs = await SharedPreferencesService.getInstance();
    final name = prefs.getUserName();
    if (name != null && mounted) _ctrl.text = name;
  }

  Future<void> _save() async {
    final name = _ctrl.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'profile.name_required'.tr());
      return;
    }
    setState(() { _saving = true; _error = null; });
    final prefs = await SharedPreferencesService.getInstance();
    await prefs.setUserName(name);
    if (!mounted) return;
    setState(() => _saving = false);
    Navigator.of(context).pop(name);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return SheetKeyboardDismissible(
      dismissBehavior: const SheetKeyboardDismissBehavior.onDragDown(),
      child: Sheet(
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
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Column(
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
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
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
                                    colors: [cs.primary, Colors.deepPurple]),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(Icons.person_rounded,
                                  color: Colors.white, size: 22),
                            ),
                            const SizedBox(width: 14),
                            Text(
                              'profile.edit_profile'.tr(),
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
                        child: Text(
                          'profile.name_label'.tr(),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: cs.onSurface.withValues(alpha: 0.6),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      FadeInUp(
                        delay: const Duration(milliseconds: 150),
                        child: TextField(
                          controller: _ctrl,
                          autofocus: true,
                          onChanged: (_) {
                            if (_error != null) setState(() => _error = null);
                          },
                          decoration: InputDecoration(
                            hintText: 'profile.name_hint'.tr(),
                            errorText: _error,
                            prefixIcon:
                                Icon(Icons.badge_outlined, color: cs.primary),
                            filled: true,
                            fillColor: cs.surfaceContainerLow,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide:
                                  BorderSide(color: cs.primary, width: 2),
                            ),
                            errorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide:
                                  BorderSide(color: cs.error, width: 1.5),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      FadeInUp(
                        delay: const Duration(milliseconds: 200),
                        child: SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: _saving ? null : _save,
                            style: FilledButton.styleFrom(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                            ),
                            child: _saving
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white))
                                : Text('common.save'.tr(),
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      FadeInUp(
                        delay: const Duration(milliseconds: 250),
                        child: SizedBox(
                          width: double.infinity,
                          child: TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: Text('common.cancel'.tr()),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
