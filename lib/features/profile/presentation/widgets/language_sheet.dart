import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:animate_do/animate_do.dart';
import 'package:smooth_sheets/smooth_sheets.dart';

// ---------------------------------------------------------------------------
// Language Picker Sheet — changes locale in-place via easy_localization
// ---------------------------------------------------------------------------

Future<void> showLanguageSheet(BuildContext context) {
  return Navigator.push(
    context,
    ModalSheetRoute(
      builder: (_) => const LanguageSheet(),
    ),
  );
}

class LanguageSheet extends StatelessWidget {
  const LanguageSheet({super.key});

  static const _languages = [
    {'code': 'en', 'nameEn': 'English', 'nameNative': 'English', 'flag': '🇬🇧'},
    {'code': 'ar', 'nameEn': 'Arabic', 'nameNative': 'العربية', 'flag': '🇸🇦'},
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final currentCode = context.locale.languageCode;

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
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FadeInDown(
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(colors: [cs.primary, Colors.deepPurple]),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(Icons.language_rounded, color: Colors.white, size: 22),
                          ),
                          const SizedBox(width: 14),
                          Text(
                            'profile.lang_title'.tr(),
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: cs.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    ...List.generate(_languages.length, (i) {
                      final lang = _languages[i];
                      final isSelected = currentCode == lang['code'];
                      return FadeInUp(
                        delay: Duration(milliseconds: 80 * i),
                        child: _LangTile(
                          flag: lang['flag']!,
                          nameEn: lang['nameEn']!,
                          nameNative: lang['nameNative']!,
                          isSelected: isSelected,
                          onTap: () async {
                            await context.setLocale(Locale(lang['code']!));
                            if (context.mounted) Navigator.of(context).pop();
                          },
                        ),
                      );
                    }),
                    const SizedBox(height: 24),
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

class _LangTile extends StatelessWidget {
  const _LangTile({
    required this.flag,
    required this.nameEn,
    required this.nameNative,
    required this.isSelected,
    required this.onTap,
  });

  final String flag;
  final String nameEn;
  final String nameNative;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? cs.primary.withValues(alpha: 0.1)
              : cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? cs.primary : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Text(flag, style: const TextStyle(fontSize: 28)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    nameEn,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: cs.onSurface,
                    ),
                  ),
                  Text(
                    nameNative,
                    style: TextStyle(
                      fontSize: 13,
                      color: cs.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
            AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: isSelected ? 1.0 : 0.0,
              child: Icon(Icons.check_circle_rounded, color: cs.primary, size: 22),
            ),
          ],
        ),
      ),
    );
  }
}
