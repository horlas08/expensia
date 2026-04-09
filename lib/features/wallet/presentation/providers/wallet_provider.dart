import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/wallet_entity.dart';

// ---------------------------------------------------------------------------
// Seed data (replaces SQLite for prototype — matches old WalletEntity shape)
// ---------------------------------------------------------------------------
final _seedWallets = [
  const WalletEntity(
    id: 1,
    name: 'Main Cash',
    type: 'cash',
    balance: 2100.00,
    currencyCode: 'USD',
    currencySymbol: '\$',
    currencyNameEn: 'US Dollar',
    rateToUsd: 1.0,
  ),
  const WalletEntity(
    id: 2,
    name: 'Bank Account',
    type: 'bank',
    balance: 8450.00,
    currencyCode: 'USD',
    currencySymbol: '\$',
    currencyNameEn: 'US Dollar',
    rateToUsd: 1.0,
  ),
  const WalletEntity(
    id: 3,
    name: 'Investments',
    type: 'investment',
    balance: 1900.00,
    currencyCode: 'USD',
    currencySymbol: '\$',
    currencyNameEn: 'US Dollar',
    rateToUsd: 1.0,
  ),
];

// ---------------------------------------------------------------------------
// State notifier — mirrors the actions in the old WalletBloc
// ---------------------------------------------------------------------------
class WalletNotifier extends StateNotifier<List<WalletEntity>> {
  WalletNotifier() : super(_seedWallets);

  /// Add balance to a wallet (old: WalletEvent.addBalance)
  void addBalance(int id, double amount) {
    state = [
      for (final w in state)
        if (w.id == id) w.copyWith(balance: w.balance + amount) else w,
    ];
  }

  /// Withdraw balance from a wallet (old: WalletEvent.withdrawBalance)
  void withdrawBalance(int id, double amount) {
    final wallet = state.firstWhere((w) => w.id == id);
    if (amount > wallet.balance) return; // guard — insufficient funds
    state = [
      for (final w in state)
        if (w.id == id) w.copyWith(balance: w.balance - amount) else w,
    ];
  }

  /// Transfer balance between wallets (old: WalletEvent.transferBalance)
  void transferBalance({
    required int fromId,
    required int toId,
    required double amount,
  }) {
    final from = state.firstWhere((w) => w.id == fromId);
    final to = state.firstWhere((w) => w.id == toId);
    if (amount > from.balance) return;

    // Handle currency conversion if rates differ
    final double receivedAmount = (from.rateToUsd != null && to.rateToUsd != null)
        ? amount * (from.rateToUsd! / to.rateToUsd!)
        : amount;

    state = [
      for (final w in state)
        if (w.id == fromId)
          w.copyWith(balance: w.balance - amount)
        else if (w.id == toId)
          w.copyWith(balance: w.balance + receivedAmount)
        else
          w,
    ];
  }

  /// Move all transactions from one wallet to another
  /// (old: WalletEvent.transferTransaction — in prototype just a balance move)
  void transferTransactions({required int fromId, required int toId}) {
    final from = state.firstWhere((w) => w.id == fromId);
    transferBalance(fromId: fromId, toId: toId, amount: from.balance);
  }

  /// Toggle hide balance (old: WalletEvent.toggleHideWallet)
  void toggleHide(int id) {
    state = [
      for (final w in state)
        if (w.id == id)
          w.copyWith(hide: (w.hide ?? 0) == 1 ? 0 : 1)
        else
          w,
    ];
  }

  /// Toggle lock wallet (old: WalletEvent.toggleBlocWallet)
  void toggleBloc(int id) {
    state = [
      for (final w in state)
        if (w.id == id)
          w.copyWith(bloc: (w.bloc ?? 0) == 1 ? 0 : 1)
        else
          w,
    ];
  }

  /// Update wallet name/type
  void updateWallet(int id, {String? name, String? type}) {
    state = [
      for (final w in state)
        if (w.id == id) w.copyWith(name: name, type: type) else w,
    ];
  }

  /// Delete a wallet (old: WalletEvent.deleteWallet)
  void deleteWallet(int id) {
    state = state.where((w) => w.id != id).toList();
  }

  /// Add new wallet
  void addWallet(WalletEntity wallet) {
    state = [...state, wallet];
  }
}

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------
final walletProvider =
    StateNotifierProvider<WalletNotifier, List<WalletEntity>>(
  (ref) => WalletNotifier(),
);

/// Convenience: total balance across all wallets
final totalBalanceProvider = Provider<double>((ref) {
  final wallets = ref.watch(walletProvider);
  return wallets.fold(0.0, (sum, w) => sum + w.balance);
});
