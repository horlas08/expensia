import 'package:flutter/material.dart';

// ---------------------------------------------------------------------------
// Category Icons — consistent set matching transaction categories in DB.
// These match the categories seeded in database_service.dart.
// Do NOT use external icon picker assets — use only these Material icons.
// ---------------------------------------------------------------------------
class CategoryIcons {
  CategoryIcons._();

  static const Map<String, IconData> map = {
    // Income
    'salary':       Icons.work_rounded,
    'freelance':    Icons.laptop_rounded,
    'investment':   Icons.trending_up_rounded,
    'bonus':        Icons.card_giftcard_rounded,
    'rental':       Icons.home_work_rounded,

    // Expenses
    'food':         Icons.restaurant_rounded,
    'groceries':    Icons.shopping_basket_rounded,
    'transport':    Icons.directions_car_rounded,
    'fuel':         Icons.local_gas_station_rounded,
    'shopping':     Icons.shopping_bag_rounded,
    'health':       Icons.favorite_rounded,
    'pharmacy':     Icons.medical_services_rounded,
    'entertainment': Icons.movie_rounded,
    'bills':        Icons.receipt_long_rounded,
    'utilities':    Icons.bolt_rounded,
    'education':    Icons.school_rounded,
    'travel':       Icons.flight_rounded,
    'sports':       Icons.fitness_center_rounded,
    'savings':      Icons.savings_rounded,
    'gift':         Icons.redeem_rounded,
    'subscriptions': Icons.subscriptions_rounded,
    'rent':         Icons.apartment_rounded,
    'insurance':    Icons.security_rounded,
    'taxes':        Icons.account_balance_rounded,
    'debt':         Icons.money_off_rounded,
    'installment':  Icons.credit_card_rounded,

    // Default
    'other':        Icons.more_horiz_rounded,
  };

  /// Returns the icon for a category name (case-insensitive).
  /// Falls back to [Icons.category_rounded] if not found.
  static IconData getIcon(String? category) {
    if (category == null) return Icons.category_rounded;
    return map[category.toLowerCase().trim()] ?? Icons.category_rounded;
  }

  /// Returns a color suitable for the category.
  static Color getColor(String? category) {
    switch ((category ?? '').toLowerCase().trim()) {
      case 'food':
      case 'groceries':
        return const Color(0xFFFF6B6B);
      case 'transport':
      case 'fuel':
        return const Color(0xFF4ECDC4);
      case 'shopping':
        return const Color(0xFFFFBE0B);
      case 'health':
      case 'pharmacy':
        return const Color(0xFFFF6B9D);
      case 'entertainment':
        return const Color(0xFF9B5DE5);
      case 'bills':
      case 'utilities':
        return const Color(0xFFF15BB5);
      case 'education':
        return const Color(0xFF00BBF9);
      case 'travel':
        return const Color(0xFF00F5D4);
      case 'salary':
      case 'freelance':
        return const Color(0xFF00C48C);
      case 'investment':
        return const Color(0xFF6B4EFF);
      case 'savings':
        return const Color(0xFF1AAF5D);
      case 'debt':
      case 'installment':
        return const Color(0xFFFF4757);
      default:
        return const Color(0xFF8C8FA5);
    }
  }
}
