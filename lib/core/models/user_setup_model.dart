class UserSetupModel {
  final String name;
  final int defaultCurrency;
  final double cash;
  final double salary;
  final int dayOfSalary;
  final bool autoAddSalary;
  final bool startThisMonth;
  final bool isOptions;

  UserSetupModel({
    required this.name,
    required this.defaultCurrency,
    required this.cash,
    required this.salary,
    required this.dayOfSalary,
    required this.autoAddSalary,
    required this.startThisMonth,
    required this.isOptions,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'defaultCurrency': defaultCurrency,
      'cash': cash,
      'salary': salary,
      'dayOfSalary': dayOfSalary,
      'autoAddSalary': autoAddSalary,
      'startThisMonth': startThisMonth,
      'isOptions': isOptions,
    };
  }

  factory UserSetupModel.fromMap(Map<String, dynamic> map) {
    return UserSetupModel(
      name: map['name'] ?? '',
      defaultCurrency: map['defaultCurrency'] ?? 1,
      cash: map['cash']?.toDouble() ?? 0.0,
      salary: map['salary']?.toDouble() ?? 0.0,
      dayOfSalary: map['dayOfSalary'] ?? 1,
      autoAddSalary: map['autoAddSalary'] ?? false,
      startThisMonth: map['startThisMonth'] ?? false,
      isOptions: map['isOptions'] ?? false,
    );
  }
}

class CurrencyModel {
  final int id;
  final String currencyNameAr;
  final String currencyNameEn;
  final String countryCode;
  final String currencyCode;
  final String currencySymbol;
  final double rateToUsd;
  final String flag;

  CurrencyModel({
    required this.id,
    required this.currencyNameAr,
    required this.currencyNameEn,
    required this.countryCode,
    required this.currencyCode,
    required this.currencySymbol,
    required this.rateToUsd,
    required this.flag,
  });

  factory CurrencyModel.fromMap(Map<String, dynamic> map) {
    return CurrencyModel(
      id: map['id'],
      currencyNameAr: map['currency_name_ar'] ?? '',
      currencyNameEn: map['currency_name_en'] ?? '',
      countryCode: map['country_code'] ?? '',
      currencyCode: map['currency_code'] ?? '',
      currencySymbol: map['currency_symbol'] ?? '',
      rateToUsd: map['rate_to_usd']?.toDouble() ?? 1.0,
      flag: map['flag'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'currency_name_ar': currencyNameAr,
      'currency_name_en': currencyNameEn,
      'country_code': countryCode,
      'currency_code': currencyCode,
      'currency_symbol': currencySymbol,
      'rate_to_usd': rateToUsd,
      'flag': flag,
    };
  }

  String get displayName => currencyNameEn.isNotEmpty ? currencyNameEn : currencyNameAr;
}
