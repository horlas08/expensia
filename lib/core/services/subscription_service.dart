import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';

import 'shared_preferences_service.dart';

/// Provider for the Subscription Service
final subscriptionServiceProvider = Provider<SubscriptionService>((ref) {
  final service = SubscriptionService();
  ref.onDispose(service.dispose);
  return service;
});

/// Provider for the user's Pro status
final isProProvider = StateProvider<bool>((ref) => false);

enum SubscriptionPackageType { yearly, lifetime }

class SubscriptionPackage {
  const SubscriptionPackage({
    required this.productId,
    required this.title,
    required this.description,
    required this.priceString,
    required this.rawPrice,
    required this.type,
    required this.productDetails,
  });

  final String productId;
  final String title;
  final String description;
  final String priceString;
  final double rawPrice;
  final SubscriptionPackageType type;
  final ProductDetails productDetails;
}

class SubscriptionService {
  SubscriptionService() {
    _purchaseSubscription = _inAppPurchase.purchaseStream.listen(
      _handlePurchaseUpdates,
      onError: (Object error) {
        debugPrint('Purchase stream error: $error');
        _completePurchaseFlow(false);
      },
    );
  }

  // Update these IDs if your Google Play product IDs are different.
  static const String yearlyProductId = 'yearly';
  static const String lifetimeProductId = 'lifetime';
  static const Set<String> _productIds = <String>{
    yearlyProductId,
    lifetimeProductId,
  };

  final InAppPurchase _inAppPurchase = InAppPurchase.instance;

  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;
  SharedPreferencesService? _preferences;
  bool _isInitialized = false;
  Completer<bool>? _purchaseCompleter;
  String? _pendingProductId;

  Future<void> init() async {
    if (_isInitialized) {
      return;
    }

    try {
      _preferences ??= await SharedPreferencesService.getInstance();
      await checkEntitlements();
      _isInitialized = true;
    } catch (e) {
      debugPrint('Error initializing SubscriptionService: $e');
    }
  }

  Future<bool> checkEntitlements() async {
    _preferences ??= await SharedPreferencesService.getInstance();

    try {
      if (!await _inAppPurchase.isAvailable()) {
        return _preferences!.isPro();
      }

      if (Platform.isAndroid) {
        final InAppPurchaseAndroidPlatformAddition addition =
            _inAppPurchase
                .getPlatformAddition<InAppPurchaseAndroidPlatformAddition>();
        final QueryPurchaseDetailsResponse response =
            await addition.queryPastPurchases();

        if (response.error != null && response.pastPurchases.isEmpty) {
          return _preferences!.isPro();
        }

        final bool isPro = response.pastPurchases.any(_isUnlockedPurchase);
        await _preferences!.setIsPro(isPro);
        return isPro;
      }

      return _preferences!.isPro();
    } catch (e) {
      debugPrint('Failed to check entitlements: $e');
      return _preferences!.isPro();
    }
  }

  Future<List<SubscriptionPackage>> getPackages() async {
    try {
      if (!await _inAppPurchase.isAvailable()) {
        return <SubscriptionPackage>[];
      }

      final ProductDetailsResponse response = await _inAppPurchase
          .queryProductDetails(_productIds);

      if (response.error != null) {
        debugPrint('Failed to fetch products: ${response.error}');
      }

      final Map<String, ProductDetails> productsById =
          <String, ProductDetails>{};
      for (final ProductDetails product in response.productDetails) {
        if (_productIds.contains(product.id) &&
            !productsById.containsKey(product.id)) {
          productsById[product.id] = product;
        }
      }

      final List<SubscriptionPackage> packages = <SubscriptionPackage>[];

      final ProductDetails? yearlyProduct = productsById[yearlyProductId];
      if (yearlyProduct != null) {
        packages.add(
          SubscriptionPackage(
            productId: yearlyProduct.id,
            title: yearlyProduct.title,
            description: yearlyProduct.description,
            priceString: yearlyProduct.price,
            rawPrice: yearlyProduct.rawPrice,
            type: SubscriptionPackageType.yearly,
            productDetails: yearlyProduct,
          ),
        );
      }

      final ProductDetails? lifetimeProduct = productsById[lifetimeProductId];
      if (lifetimeProduct != null) {
        packages.add(
          SubscriptionPackage(
            productId: lifetimeProduct.id,
            title: lifetimeProduct.title,
            description: lifetimeProduct.description,
            priceString: lifetimeProduct.price,
            rawPrice: lifetimeProduct.rawPrice,
            type: SubscriptionPackageType.lifetime,
            productDetails: lifetimeProduct,
          ),
        );
      }

      return packages;
    } catch (e) {
      debugPrint('Failed to fetch packages: $e');
      return <SubscriptionPackage>[];
    }
  }

  Future<bool> purchasePackage(SubscriptionPackage package) async {
    try {
      if (!await _inAppPurchase.isAvailable()) {
        return false;
      }

      _pendingProductId = package.productId;
      _purchaseCompleter = Completer<bool>();

      final PurchaseParam purchaseParam = PurchaseParam(
        productDetails: package.productDetails,
      );

      final bool launched = await _inAppPurchase.buyNonConsumable(
        purchaseParam: purchaseParam,
      );

      if (!launched) {
        _completePurchaseFlow(false);
        return false;
      }

      return _purchaseCompleter!.future.timeout(
        const Duration(seconds: 45),
        onTimeout: () {
          _completePurchaseFlow(false);
          return false;
        },
      );
    } catch (e) {
      debugPrint('Purchase failed: $e');
      _completePurchaseFlow(false);
      return false;
    }
  }

  Future<bool> restorePurchases() async {
    _preferences ??= await SharedPreferencesService.getInstance();

    try {
      if (!await _inAppPurchase.isAvailable()) {
        return _preferences!.isPro();
      }

      if (Platform.isAndroid) {
        return await checkEntitlements();
      }

      await _inAppPurchase.restorePurchases();
      await Future<void>.delayed(const Duration(seconds: 2));
      return _preferences!.isPro();
    } catch (e) {
      debugPrint('Restore failed: $e');
      return _preferences!.isPro();
    }
  }

  Future<void> _handlePurchaseUpdates(
    List<PurchaseDetails> purchaseDetailsList,
  ) async {
    for (final PurchaseDetails purchase in purchaseDetailsList) {
      if (!_productIds.contains(purchase.productID)) {
        continue;
      }

      switch (purchase.status) {
        case PurchaseStatus.pending:
          continue;
        case PurchaseStatus.error:
        case PurchaseStatus.canceled:
          _completePurchaseFlow(false);
          break;
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          _preferences ??= await SharedPreferencesService.getInstance();
          await _preferences?.setIsPro(true);
          if (purchase.pendingCompletePurchase) {
            await _inAppPurchase.completePurchase(purchase);
          }
          if (_pendingProductId == null ||
              _pendingProductId == purchase.productID) {
            _completePurchaseFlow(true);
          }
          break;
      }
    }
  }

  bool _isUnlockedPurchase(PurchaseDetails purchase) {
    return _productIds.contains(purchase.productID) &&
        (purchase.status == PurchaseStatus.purchased ||
            purchase.status == PurchaseStatus.restored);
  }

  void _completePurchaseFlow(bool success) {
    if (_purchaseCompleter != null && !_purchaseCompleter!.isCompleted) {
      _purchaseCompleter!.complete(success);
    }
    _purchaseCompleter = null;
    _pendingProductId = null;
  }

  void dispose() {
    _purchaseSubscription?.cancel();
  }
}
