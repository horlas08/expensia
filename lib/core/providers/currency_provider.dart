import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_setup_model.dart';
import '../services/currency_catalog_service.dart';
import '../services/shared_preferences_service.dart';

// ---------------------------------------------------------------------------
// Global currency provider — reads saved default currency from SharedPrefs
// ---------------------------------------------------------------------------

final currencyCatalogProvider = FutureProvider<List<CurrencyModel>>((
  ref,
) async {
  return CurrencyCatalogService().loadCurrencies();
});

/// The full CurrencyModel for the user's chosen default currency.
/// Returns null if none has been set yet.
final defaultCurrencyProvider = FutureProvider<CurrencyModel?>((ref) async {
  final prefs = await SharedPreferencesService.getInstance();
  return prefs.getDefaultCurrency();
});

/// Convenience provider: just the currency symbol (e.g. "$", "€", "﷼").
/// Falls back to "$" if no currency has been saved.
/// NOTE: Currency symbols are static strings — never use .tr() on them.
final currencySymbolProvider = Provider<String>((ref) {
  final asyncCurrency = ref.watch(defaultCurrencyProvider);
  return asyncCurrency.when(
    data: (currency) => currency?.currencySymbol ?? '\$',
    loading: () => '\$',
    error: (_, __) => '\$',
  );
});

/// Convenience provider: just the currency code (e.g. "USD", "EUR").
/// Falls back to "USD" if no currency has been saved.
final currencyCodeProvider = Provider<String>((ref) {
  final asyncCurrency = ref.watch(defaultCurrencyProvider);
  return asyncCurrency.when(
    data: (currency) => currency?.currencyCode ?? 'USD',
    loading: () => 'USD',
    error: (_, __) => 'USD',
  );
});
