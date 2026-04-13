import 'package:flutter_riverpod/flutter_riverpod.dart';

// ── Filter Model ─────────────────────────────────────────────────────────────

class TransactionFilter {
  final String? type;         // 'transaction', 'transfer', 'debt', 'installment'
  final String? direction;    // 'plus', 'min'
  final int? categoryId;
  final String? categoryName;
  final int? walletId;
  final String? walletName;
  final int? personId;
  final String? personName;
  final DateTime? fromDate;
  final DateTime? toDate;
  final bool? isPaid;         // for debt/installment

  const TransactionFilter({
    this.type,
    this.direction,
    this.categoryId,
    this.categoryName,
    this.walletId,
    this.walletName,
    this.personId,
    this.personName,
    this.fromDate,
    this.toDate,
    this.isPaid,
  });

  TransactionFilter copyWith({
    Object? type = _sentinel,
    Object? direction = _sentinel,
    Object? categoryId = _sentinel,
    Object? categoryName = _sentinel,
    Object? walletId = _sentinel,
    Object? walletName = _sentinel,
    Object? personId = _sentinel,
    Object? personName = _sentinel,
    Object? fromDate = _sentinel,
    Object? toDate = _sentinel,
    Object? isPaid = _sentinel,
  }) {
    return TransactionFilter(
      type: identical(type, _sentinel) ? this.type : type as String?,
      direction: identical(direction, _sentinel) ? this.direction : direction as String?,
      categoryId: identical(categoryId, _sentinel) ? this.categoryId : categoryId as int?,
      categoryName: identical(categoryName, _sentinel) ? this.categoryName : categoryName as String?,
      walletId: identical(walletId, _sentinel) ? this.walletId : walletId as int?,
      walletName: identical(walletName, _sentinel) ? this.walletName : walletName as String?,
      personId: identical(personId, _sentinel) ? this.personId : personId as int?,
      personName: identical(personName, _sentinel) ? this.personName : personName as String?,
      fromDate: identical(fromDate, _sentinel) ? this.fromDate : fromDate as DateTime?,
      toDate: identical(toDate, _sentinel) ? this.toDate : toDate as DateTime?,
      isPaid: identical(isPaid, _sentinel) ? this.isPaid : isPaid as bool?,
    );
  }

  bool get isEmpty =>
      type == null &&
      direction == null &&
      categoryId == null &&
      walletId == null &&
      personId == null &&
      fromDate == null &&
      toDate == null &&
      isPaid == null;

  int get activeCount {
    int count = 0;
    if (type != null) count++;
    if (direction != null) count++;
    if (categoryId != null) count++;
    if (walletId != null) count++;
    if (personId != null) count++;
    if (fromDate != null || toDate != null) count++;
    if (isPaid != null) count++;
    return count;
  }

  static const TransactionFilter empty = TransactionFilter();
}

const _sentinel = Object();

// ── Filter Notifier ───────────────────────────────────────────────────────────

class TransactionFilterNotifier extends StateNotifier<TransactionFilter> {
  TransactionFilterNotifier() : super(TransactionFilter.empty);

  void setType(String? type) => state = state.copyWith(type: type);
  void setDirection(String? direction) => state = state.copyWith(direction: direction);
  void setCategory(int? id, String? name) => state = state.copyWith(categoryId: id, categoryName: name);
  void setWallet(int? id, String? name) => state = state.copyWith(walletId: id, walletName: name);
  void setPerson(int? id, String? name) => state = state.copyWith(personId: id, personName: name);
  void setFromDate(DateTime? date) => state = state.copyWith(fromDate: date);
  void setToDate(DateTime? date) => state = state.copyWith(toDate: date);
  void setIsPaid(bool? isPaid) => state = state.copyWith(isPaid: isPaid);
  void reset() => state = TransactionFilter.empty;
}

final transactionFilterProvider =
    StateNotifierProvider<TransactionFilterNotifier, TransactionFilter>(
  (ref) => TransactionFilterNotifier(),
);
