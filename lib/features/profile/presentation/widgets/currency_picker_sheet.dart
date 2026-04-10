import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:animate_do/animate_do.dart';
import 'package:smooth_sheets/smooth_sheets.dart';
import '../../../../core/models/user_setup_model.dart';
import '../../../../core/services/shared_preferences_service.dart';
import '../../../../core/providers/currency_provider.dart';

// ---------------------------------------------------------------------------
// Currency Picker Sheet — changes default currency from profile
// NOTE: Currency symbols ($ € £ etc.) are static strings, NOT translated.
// ---------------------------------------------------------------------------

Future<void> showCurrencyPickerSheet(BuildContext context, WidgetRef ref) {
  return Navigator.push(
    context,
    ModalSheetRoute(
      builder: (_) => CurrencyPickerSheet(ref: ref),
    ),
  );
}

class CurrencyPickerSheet extends ConsumerStatefulWidget {
  const CurrencyPickerSheet({super.key, required this.ref});
  final WidgetRef ref;

  @override
  ConsumerState<CurrencyPickerSheet> createState() => _CurrencyPickerSheetState();
}

class _CurrencyPickerSheetState extends ConsumerState<CurrencyPickerSheet> {
  CurrencyModel? _selected;
  bool _saving = false;

  // Same currency list as setup_page.dart — kept in sync manually
  static final List<CurrencyModel> _currencies = [
    CurrencyModel(id: 1, currencyNameAr: 'دولار أمريكي', currencyNameEn: 'US Dollar',     countryCode: 'US', currencyCode: 'USD', currencySymbol: '\$',   rateToUsd: 1.0,   flag: '🇺🇸'),
    CurrencyModel(id: 2, currencyNameAr: 'يورو',          currencyNameEn: 'Euro',          countryCode: 'EU', currencyCode: 'EUR', currencySymbol: '€',   rateToUsd: 0.85,  flag: '🇪🇺'),
    CurrencyModel(id: 3, currencyNameAr: 'جنيه إسترليني', currencyNameEn: 'British Pound', countryCode: 'GB', currencyCode: 'GBP', currencySymbol: '£',   rateToUsd: 0.73,  flag: '🇬🇧'),
    CurrencyModel(id: 4, currencyNameAr: 'ين ياباني',     currencyNameEn: 'Japanese Yen',  countryCode: 'JP', currencyCode: 'JPY', currencySymbol: '¥',   rateToUsd: 110.0, flag: '🇯🇵'),
    CurrencyModel(id: 5, currencyNameAr: 'ريال سعودي',    currencyNameEn: 'Saudi Riyal',   countryCode: 'SA', currencyCode: 'SAR', currencySymbol: '﷼',  rateToUsd: 3.75,  flag: '🇸🇦'),
    CurrencyModel(id: 6, currencyNameAr: 'درهم إماراتي',  currencyNameEn: 'UAE Dirham',    countryCode: 'AE', currencyCode: 'AED', currencySymbol: 'د.إ', rateToUsd: 3.67,  flag: '🇦🇪'),
    CurrencyModel(id: 7, currencyNameAr: 'جنيه مصري',     currencyNameEn: 'Egyptian Pound',countryCode: 'EG', currencyCode: 'EGP', currencySymbol: 'ج.م', rateToUsd: 15.7,  flag: '🇪🇬'),
  ];

  @override
  void initState() {
    super.initState();
    _loadCurrent();
  }

  Future<void> _loadCurrent() async {
    final prefs = await SharedPreferencesService.getInstance();
    final curr = prefs.getDefaultCurrency();
    if (curr != null && mounted) {
      setState(() => _selected = curr);
    }
  }

  Future<void> _save() async {
    if (_selected == null) return;
    setState(() => _saving = true);
    final prefs = await SharedPreferencesService.getInstance();
    await prefs.setDefaultCurrency(_selected!);
    ref.invalidate(defaultCurrencyProvider);
    if (!mounted) return;
    setState(() => _saving = false);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final locale = context.locale.languageCode;

    return Sheet(
      initialOffset: const SheetOffset(1),
      snapGrid: const SheetSnapGrid.stepless(
        minOffset: SheetOffset(0.5),
      ),
      child: SheetContentScaffold(
        body: Container(
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
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
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                child: FadeInDown(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [cs.primary, Colors.deepPurple]),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.currency_exchange_rounded, color: Colors.white, size: 22),
                      ),
                      const SizedBox(width: 14),
                      Text(
                        'profile.currency_title'.tr(),
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: cs.onSurface),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _currencies.length,
                  itemBuilder: (context, i) {
                    final c = _currencies[i];
                    final isSelected = _selected?.currencyCode == c.currencyCode;
                    final name = locale == 'ar' ? c.currencyNameAr : c.currencyNameEn;
                    return FadeInUp(
                      delay: Duration(milliseconds: 50 * i),
                      child: GestureDetector(
                        onTap: () => setState(() => _selected = c),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: isSelected ? cs.primary.withValues(alpha: 0.1) : cs.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected ? cs.primary : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: Row(
                            children: [
                              Text(c.flag, style: const TextStyle(fontSize: 26)),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(name, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: cs.onSurface)),
                                    // Symbol is a static character — not translated
                                    Text('${c.currencyCode}  •  ${c.currencySymbol}', style: TextStyle(fontSize: 13, color: cs.onSurface.withValues(alpha: 0.5))),
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
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(24, 8, 24, MediaQuery.of(context).padding.bottom + 16),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: (_selected == null || _saving) ? null : _save,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: _saving
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text('common.save'.tr(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
