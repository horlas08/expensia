import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/widgets.dart';

import '../../domain/entities/wallet_entity.dart';

const Map<String, Set<String>> _builtInWalletNameKeys = {
  'setup.cash_wallet_name': {'Cash', 'نقدية'},
  'setup.salary_account_name': {'Salary Account', 'حساب الراتب'},
};

String localizedWalletDisplayName(BuildContext context, String rawName) {
  final normalizedName = rawName.trim();

  for (final entry in _builtInWalletNameKeys.entries) {
    if (entry.value.contains(normalizedName)) {
      return entry.key.tr(context: context);
    }
  }

  return rawName;
}

extension WalletDisplayNameX on WalletEntity {
  String displayName(BuildContext context) {
    return localizedWalletDisplayName(context, name);
  }

  String localizedCurrencyName(BuildContext context) {
    final locale = Localizations.localeOf(context).languageCode;
    if (locale == 'ar' &&
        currencyNameAr != null &&
        currencyNameAr!.isNotEmpty) {
      return currencyNameAr!;
    }
    return currencyNameEn ?? '';
  }
}
