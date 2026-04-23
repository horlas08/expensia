import 'package:flutter/material.dart';

// ---------------------------------------------------------------------------
// Category Icons — consistent set matching transaction categories in DB.
// These match the categories seeded in database_service.dart.
// Do NOT use external icon picker assets — use only these Material icons.
// ---------------------------------------------------------------------------
class CategoryIcons {
  CategoryIcons._();

  static const Map<String, IconData> map = {
    // System & General
    'with_draw':           Icons.account_balance_wallet_rounded,
    'transfer':            Icons.swap_horiz_rounded,
    'debt':                Icons.money_off_rounded,
    'receive_debt':        Icons.monetization_on_rounded,

    // Installments
    'installment':         Icons.credit_score_rounded,
    'receive_installment': Icons.payments_rounded,

    // Income
    'salary':       Icons.work_rounded,
    'bonus':        Icons.card_giftcard_rounded,
    'business':     Icons.business_center_rounded,
    'investment':   Icons.trending_up_rounded,
    'gift':         Icons.redeem_rounded,
    'other':        Icons.more_horiz_rounded,

    // Expenses - Housing
    'housing':      Icons.home_rounded,
    'rent':         Icons.apartment_rounded,
    'mortgage':     Icons.home_work_rounded,
    'utilities':    Icons.bolt_rounded,
    'maintenance':  Icons.build_rounded,
    'tax':          Icons.account_balance_rounded,

    // Expenses - Utilities & Bills
    'bills':        Icons.receipt_long_rounded,
    'electricity':  Icons.flash_on_rounded,
    'water':        Icons.opacity_rounded,
    'internet':     Icons.language_rounded,
    'mobile':       Icons.smartphone_rounded,

    // Expenses - Transportation
    'transport':    Icons.directions_car_rounded,
    'fuel':         Icons.local_gas_station_rounded,
    'maintenance_car': Icons.settings_suggest_rounded,
    'insurance_car': Icons.security_rounded,
    'parking':      Icons.local_parking_rounded,
    'bus':          Icons.directions_bus_rounded,
    'fine':         Icons.gavel_rounded,

    // Expenses - Food
    'food':         Icons.restaurant_rounded,
    'groceries':    Icons.shopping_basket_rounded,
    'restaurants':  Icons.restaurant_menu_rounded,
    'coffee':       Icons.coffee_rounded,

    // Expenses - Health
    'health':       Icons.medical_services_rounded,
    'hospital':     Icons.local_hospital_rounded,
    'pharmacy':     Icons.local_pharmacy_rounded,
    'health_insurance': Icons.health_and_safety_rounded,

    // Expenses - Education
    'education':    Icons.school_rounded,
    'tuition':      Icons.account_balance_rounded,
    'books':        Icons.menu_book_rounded,
    'course':       Icons.auto_stories_rounded,

    // Expenses - Personal Care
    'personal_care': Icons.face_retouching_natural_rounded,
    'clothes':      Icons.checkroom_rounded,
    'barber':       Icons.content_cut_rounded,
    'cosmetics':    Icons.brush_rounded,

    // Expenses - Entertainment
    'entertainment': Icons.movie_rounded,
    'subscriptions': Icons.subscriptions_rounded,
    'cinema':       Icons.theaters_rounded,
    'hobby':        Icons.palette_rounded,

    // Expenses - Family & Kids
    'family':       Icons.family_restroom_rounded,
    'childcare':    Icons.child_care_rounded,
    'school':       Icons.location_city_rounded,
    'toys':         Icons.toys_rounded,

    // Expenses - Pets
    'pets':         Icons.pets_rounded,
    'pet_food':     Icons.set_meal_rounded,
    'vet':          Icons.medical_services_rounded,

    // Expenses - Gifts & Donations
    'gifts_given':  Icons.card_giftcard_rounded,
    'gift_box':     Icons.redeem_rounded,
    'charity':      Icons.volunteer_activism_rounded,

    // Expenses - Savings & Investments
    'savings_invest': Icons.savings_rounded,
    'emergency':    Icons.emergency_rounded,
    'retirement':   Icons.elderly_rounded,
    'stocks':       Icons.show_chart_rounded,

    // Expenses - Debt & Loans
    'debt_loans':   Icons.request_quote_rounded,
    'loan_payment': Icons.payments_rounded,
    'credit_card_pay': Icons.credit_card_rounded,

    // Expenses - Insurance
    'insurance':    Icons.verified_user_rounded,
    'health_insurance_alt': Icons.health_and_safety_rounded,
    'car_insurance': Icons.car_crash_rounded,
    'life_insurance': Icons.admin_panel_settings_rounded,

    // Expenses - Miscellaneous
    'misc':         Icons.category_rounded,
    'unplanned':    Icons.help_outline_rounded,
    'other_expense': Icons.more_horiz_rounded,
  };

  /// Returns the icon for a category image name (case-insensitive).
  /// Falls back to [Icons.category_rounded] if not found.
  static IconData getIcon(String? imageName) {
    if (imageName == null) return Icons.category_rounded;
    return map[imageName.toLowerCase().trim()] ?? Icons.category_rounded;
  }

  /// Returns a color suitable for the category based on image name or general type.
  static Color getColor(String? imageName) {
    switch ((imageName ?? '').toLowerCase().trim()) {
      case 'salary':
      case 'bonus':
      case 'business':
      case 'investment':
        return const Color(0xFF00C48C);
      case 'housing':
      case 'rent':
      case 'mortgage':
      case 'maintenance':
        return const Color(0xFF4A90E2);
      case 'food':
      case 'groceries':
      case 'restaurants':
      case 'coffee':
        return const Color(0xFFFF6B6B);
      case 'transport':
      case 'fuel':
      case 'bus':
        return const Color(0xFF4ECDC4);
      case 'health':
      case 'pharmacy':
      case 'hospital':
        return const Color(0xFFFF6B9D);
      case 'entertainment':
      case 'cinema':
      case 'hobby':
      case 'subscriptions':
        return const Color(0xFF9B5DE5);
      case 'education':
      case 'tuition':
      case 'books':
        return const Color(0xFF00BBF9);
      case 'personal_care':
      case 'clothes':
      case 'barber':
        return const Color(0xFFF15BB5);
      case 'family':
      case 'childcare':
      case 'school':
      case 'toys':
        return const Color(0xFFFFBE0B);
      case 'pets':
      case 'pet_food':
      case 'vet':
        return const Color(0xFFE67E22);
      case 'debt':
      case 'debt_loans':
      case 'loan_payment':
      case 'credit_card_pay':
        return const Color(0xFFFF4757);
      case 'savings_invest':
      case 'savings':
      case 'emergency':
      case 'retirement':
      case 'stocks':
        return const Color(0xFF1AAF5D);
      case 'insurance':
      case 'car_insurance':
      case 'life_insurance':
        return const Color(0xFF5D6D7E);
      case 'bills':
      case 'utilities':
      case 'electricity':
      case 'water':
      case 'internet':
      case 'mobile':
        return const Color(0xFF3498DB);
      default:
        return const Color(0xFF8C8FA5);
    }
  }
}
