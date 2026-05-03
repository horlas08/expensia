import 'package:flutter/material.dart';

import 'package:easy_localization/easy_localization.dart';

import '../config/premium_config.dart';
import 'rewarded_ad_service.dart';
import 'shared_preferences_service.dart';
import '../../features/profile/presentation/widgets/subscription_sheet.dart';
import '../../features/transactions/presentation/widgets/transaction_limit_sheet.dart';

class TransactionLimitService {
  TransactionLimitService._();

  static const String _bonusTransactionCreditsKey = 'bonus_transaction_credits';

  static Future<int> getBonusTransactionCredits() async {
    final prefs = await SharedPreferencesService.getInstance();
    return prefs.getInt(_bonusTransactionCreditsKey) ?? 0;
  }

  static Future<void> addBonusTransactionCredit([int count = 1]) async {
    final prefs = await SharedPreferencesService.getInstance();
    final current = prefs.getInt(_bonusTransactionCreditsKey) ?? 0;
    await prefs.setInt(_bonusTransactionCreditsKey, current + count);
  }

  static Future<void> consumeBonusTransactionCredit() async {
    final prefs = await SharedPreferencesService.getInstance();
    final current = prefs.getInt(_bonusTransactionCreditsKey) ?? 0;
    if (current <= 0) return;
    await prefs.setInt(_bonusTransactionCreditsKey, current - 1);
  }

  static Future<bool> ensureCanCreateTransaction({
    required BuildContext context,
    required bool isPro,
    required int currentCount,
  }) async {
    if (!PremiumConfig.hasReachedTransactionLimit(
      isPro: isPro,
      currentCount: currentCount,
    )) {
      return true;
    }

    final credits = await getBonusTransactionCredits();
    if (credits > 0) {
      await consumeBonusTransactionCredit();
      return true;
    }

    if (!context.mounted) return false;

    final action = await TransactionLimitSheet.show(context);
    if (!context.mounted || action == null) {
      return false;
    }

    if (action == TransactionLimitAction.upgrade) {
      await SubscriptionSheet.show(context);
      return false;
    }

    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    final loadingOverlay = OverlayEntry(
      builder:
          (_) => ColoredBox(
            color: Colors.black45,
            child: const Center(child: CircularProgressIndicator()),
          ),
    );
    overlay?.insert(loadingOverlay);

    try {
      final rewarded = await RewardedAdService.showRewardedTransactionAd();
      if (!rewarded) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('transaction.rewarded_ad_failed'.tr())),
          );
        }
        return false;
      }
      if (!context.mounted) {
        return false;
      }

      await addBonusTransactionCredit();
      await consumeBonusTransactionCredit();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('transaction.bonus_transaction_unlocked'.tr()),
          ),
        );
      }

      return true;
    } finally {
      loadingOverlay.remove();
    }
  }
}
