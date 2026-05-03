import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'dart:io';

/// Provider for the Subscription Service
final subscriptionServiceProvider = Provider<SubscriptionService>((ref) => SubscriptionService());

/// Provider for the user's Pro status
final isProProvider = StateProvider<bool>((ref) => false);

class SubscriptionService {
  /// TODO: Replace with your actual RevenueCat API Keys from the dashboard
  /// Android: https://app.revenuecat.com/projects/YOUR_PROJECT/apps/android/settings
  static const _apiKeyAndroid = 'test_GlYJaYSabSJvbsOYFyWWAcZOWYI';
  
  /// iOS: https://app.revenuecat.com/projects/YOUR_PROJECT/apps/ios/settings
  static const _apiKeyIos = 'test_GlYJaYSabSJvbsOYFyWWAcZOWYI';

  /// The ID of the entitlement that grants Pro access.
  /// Usually set up in RevenueCat Dashboard -> Entitlements.
  static const _proEntitlementId = 'premium';

  Future<void> init() async {
    try {
      if (kDebugMode) {
        await Purchases.setLogLevel(LogLevel.debug);
      }

      PurchasesConfiguration? configuration;
      if (Platform.isAndroid) {
        configuration = PurchasesConfiguration(_apiKeyAndroid);
      } else if (Platform.isIOS) {
        configuration = PurchasesConfiguration(_apiKeyIos);
      }

      if (configuration != null) {
        await Purchases.configure(configuration);
        await checkEntitlements();
      }
    } catch (e) {
      debugPrint('Error initializing SubscriptionService: $e');
      // We don't rethrow because it's a non-critical service for the app to start
    }
  }

  Future<bool> checkEntitlements() async {
    try {
      CustomerInfo customerInfo = await Purchases.getCustomerInfo();
      bool isPro = customerInfo.entitlements.all[_proEntitlementId]?.isActive ?? false;
      return isPro;
    } catch (e) {
      return false;
    }
  }

  Future<bool> purchasePro() async {
    try {
      Offerings offerings = await Purchases.getOfferings();
      if (offerings.current != null && offerings.current!.availablePackages.isNotEmpty) {
        final result = await Purchases.purchasePackage(
          offerings.current!.availablePackages.first,
        );
        CustomerInfo customerInfo = result.customerInfo;
        return customerInfo.entitlements.all[_proEntitlementId]?.isActive ?? false;
      }
    } catch (e) {
      debugPrint('Purchase failed: $e');
    }
    return false;
  }

  Future<bool> restorePurchases() async {
    try {
      CustomerInfo customerInfo = await Purchases.restorePurchases();
      return customerInfo.entitlements.all[_proEntitlementId]?.isActive ?? false;
    } catch (e) {
      debugPrint('Restore failed: $e');
      return false;
    }
  }
}
