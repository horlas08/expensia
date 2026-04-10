import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'dart:io';

/// Provider for the Subscription Service
final subscriptionServiceProvider = Provider<SubscriptionService>((ref) => SubscriptionService());

/// Provider for the user's Pro status
final isProProvider = StateProvider<bool>((ref) => false);

class SubscriptionService {
  static const _apiKeyAndroid = 'goog_placeholder_android_key';
  static const _apiKeyIos = 'appl_placeholder_ios_key';

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
      // 'premium' is a common entitlement ID, should match RevenueCat dashboard
      bool isPro = customerInfo.entitlements.all['premium']?.isActive ?? false;
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
        return customerInfo.entitlements.all['premium']?.isActive ?? false;
      }
    } catch (e) {
      debugPrint('Purchase failed: $e');
    }
    return false;
  }

  Future<bool> restorePurchases() async {
    try {
      CustomerInfo customerInfo = await Purchases.restorePurchases();
      return customerInfo.entitlements.all['premium']?.isActive ?? false;
    } catch (e) {
      debugPrint('Restore failed: $e');
      return false;
    }
  }
}
