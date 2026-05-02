enum PremiumFeature { appLock, googleDriveBackupRestore, statistics }

class PremiumConfig {
  const PremiumConfig._();

  static const int maxFreeTransactions = 10;
  static const int maxFreeWallets = 3;

  static bool isLocked({required PremiumFeature feature, required bool isPro}) {
    if (isPro) return false;

    switch (feature) {
      case PremiumFeature.appLock:
      case PremiumFeature.googleDriveBackupRestore:
      case PremiumFeature.statistics:
        return true;
    }
  }

  static bool hasReachedTransactionLimit({
    required bool isPro,
    required int currentCount,
  }) {
    return !isPro && currentCount >= maxFreeTransactions;
  }

  static bool hasReachedWalletLimit({
    required bool isPro,
    required int currentCount,
  }) {
    return !isPro && currentCount >= maxFreeWallets;
  }
}
