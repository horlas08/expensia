import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/user_setup_model.dart';

class CurrencyCatalogService {
  static const String _assetPath =
      'assets/currencies_one_per_country_symbols_bilingual.json';

  static List<CurrencyModel>? _cache;

  Future<List<CurrencyModel>> loadCurrencies() async {
    final cached = _cache;
    if (cached != null) return cached;

    final jsonString = await rootBundle.loadString(_assetPath);
    final decoded = jsonDecode(jsonString) as List<dynamic>;

    final currencies = decoded
        .map(
          (item) =>
              CurrencyModel.fromMap(Map<String, dynamic>.from(item as Map)),
        )
        .toList(growable: false);

    _cache = currencies;
    return currencies;
  }
}
