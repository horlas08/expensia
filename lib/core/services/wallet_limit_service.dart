import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

import '../config/premium_config.dart';
import 'rewarded_ad_service.dart';
import 'shared_preferences_service.dart';
import '../../features/profile/presentation/widgets/subscription_sheet.dart';
import '../../features/wallet/presentation/widgets/wallet_limit_sheet.dart';

class WalletLimitService {
  WalletLimitService._();

  static const String _bonusWalletCreditsKey = 'bonus_wallet_credits';

  static Future<int> getBonusWalletCredits() async {
    final prefs = await SharedPreferencesService.getInstance();
    return prefs.getInt(_bonusWalletCreditsKey) ?? 0;
  }

  static Future<void> addBonusWalletCredit([int count = 1]) async {
    final prefs = await SharedPreferencesService.getInstance();
    final current = prefs.getInt(_bonusWalletCreditsKey) ?? 0;
    await prefs.setInt(_bonusWalletCreditsKey, current + count);
  }

  static Future<void> consumeBonusWalletCredit() async {
    final prefs = await SharedPreferencesService.getInstance();
    final current = prefs.getInt(_bonusWalletCreditsKey) ?? 0;
    if (current <= 0) return;
    await prefs.setInt(_bonusWalletCreditsKey, current - 1);
  }

  /// Returns `true` if the user is allowed to create a new wallet.
  /// Shows the limit sheet (Watch Ad / Upgrade) if the free limit is reached.
  static Future<bool> ensureCanCreateWallet({
    required BuildContext context,
    required bool isPro,
    required int currentCount,
  }) async {
    if (!PremiumConfig.hasReachedWalletLimit(
      isPro: isPro,
      currentCount: currentCount,
    )) {
      return true;
    }

    // Check for previously earned bonus credits
    final credits = await getBonusWalletCredits();
    if (credits > 0) {
      await consumeBonusWalletCredit();
      return true;
    }

    if (!context.mounted) return false;

    final action = await WalletLimitSheet.show(context);
    if (!context.mounted || action == null) return false;

    if (action == WalletLimitAction.upgrade) {
      await SubscriptionSheet.show(context);
      return false;
    }

    // Show loading overlay while the ad loads
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    final loadingOverlay = OverlayEntry(
      builder: (_) => const ColoredBox(
        color: Colors.black45,
        child: Center(child: CircularProgressIndicator()),
      ),
    );
    overlay?.insert(loadingOverlay);

    try {
      final rewarded = await RewardedAdService.showRewardedTransactionAd();
      if (!rewarded) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('wallet.rewarded_ad_failed'.tr())),
          );
        }
        return false;
      }
      if (!context.mounted) return false;

      await addBonusWalletCredit();
      await consumeBonusWalletCredit();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('wallet.bonus_wallet_unlocked'.tr())),
        );
      }

      return true;
    } finally {
      loadingOverlay.remove();
    }
  }
}
