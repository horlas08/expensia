/// Wallet domain entity — ported from the legacy [WalletEntity].
class WalletEntity {
  final int id;
  final String name;

  /// 'cash' | 'bank' | 'investment' | 'other'
  final String type;
  final double balance;
  final int? currencyId;
  final String? currencyCode;
  final String? currencySymbol;
  final String? currencyNameEn;
  final String? currencyNameAr;
  final double? rateToUsd;

  /// 1 = hidden balance
  final int? hide;

  /// 1 = locked / blocked
  final int? bloc;

  const WalletEntity({
    required this.id,
    required this.name,
    required this.type,
    required this.balance,
    this.currencyId,
    this.currencyCode,
    this.currencySymbol,
    this.currencyNameEn,
    this.currencyNameAr,
    this.rateToUsd,
    this.hide,
    this.bloc,
  });

  WalletEntity copyWith({
    double? balance,
    int? hide,
    int? bloc,
    String? name,
    String? type,
  }) {
    return WalletEntity(
      id: id,
      name: name ?? this.name,
      type: type ?? this.type,
      balance: balance ?? this.balance,
      currencyId: currencyId,
      currencyCode: currencyCode,
      currencySymbol: currencySymbol,
      currencyNameEn: currencyNameEn,
      currencyNameAr: currencyNameAr,
      rateToUsd: rateToUsd,
      hide: hide ?? this.hide,
      bloc: bloc ?? this.bloc,
    );
  }
}
