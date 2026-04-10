import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/wallet_entity.dart';
import '../../../../core/services/database_service.dart';

// ---------------------------------------------------------------------------
// State notifier — mirrors the actions in the old WalletBloc
// ---------------------------------------------------------------------------
class WalletNotifier extends StateNotifier<List<WalletEntity>> {
  WalletNotifier() : super([]) {
    loadWallets();
  }

  final _dbService = DatabaseService();

  /// Load wallets from database
  Future<void> loadWallets() async {
    final data = await _dbService.getWallets();
    state = data.map((map) {
      return WalletEntity(
        id: map['id'],
        name: map['name'],
        type: map['type'],
        balance: map['balance'] ?? 0.0,
        currencyCode: map['currency_code'],
        currencySymbol: map['currency_symbol'],
        currencyNameEn: map['currency_name_en'],
        rateToUsd: map['rate_to_usd'],
        hide: map['hide'],
        bloc: map['bloc'],
      );
    }).toList();
  }

  /// Add balance to a wallet
  Future<void> addBalance(int id, double amount) async {
    final db = await _dbService.database;
    await db.rawUpdate(
      'UPDATE wallets SET balance = balance + ? WHERE id = ?',
      [amount, id],
    );
    await loadWallets();
  }

  /// Withdraw balance from a wallet
  Future<void> withdrawBalance(int id, double amount) async {
    final db = await _dbService.database;
    await db.rawUpdate(
      'UPDATE wallets SET balance = balance - ? WHERE id = ?',
      [amount, id],
    );
    await loadWallets();
  }

  /// Toggle hide balance
  Future<void> toggleHide(int id) async {
    final wallet = state.firstWhere((w) => w.id == id);
    final newHide = (wallet.hide ?? 0) == 1 ? 0 : 1;
    
    final db = await _dbService.database;
    await db.update(
      'wallets',
      {'hide': newHide},
      where: 'id = ?',
      whereArgs: [id],
    );
    await loadWallets();
  }

  /// Toggle lock wallet
  Future<void> toggleBloc(int id) async {
    final wallet = state.firstWhere((w) => w.id == id);
    final newBloc = (wallet.bloc ?? 0) == 1 ? 0 : 1;
    
    final db = await _dbService.database;
    await db.update(
      'wallets',
      {'bloc': newBloc},
      where: 'id = ?',
      whereArgs: [id],
    );
    await loadWallets();
  }

  /// Delete a wallet
  Future<void> deleteWallet(int id) async {
    final db = await _dbService.database;
    await db.delete('wallets', where: 'id = ?', whereArgs: [id]);
    await loadWallets();
  }

  /// Add a new wallet
  Future<void> addWallet(WalletEntity wallet) async {
    await _dbService.addWallet({
      'name': wallet.name,
      'type': wallet.type,
      'balance': wallet.balance,
      'currency_id': wallet.currencyId ?? 1, // Defaulting to 1 if not provided
      'hide': wallet.hide ?? 0,
      'bloc': wallet.bloc ?? 0,
      'is_visible': 1,
    });
    await loadWallets();
  }

  /// Update wallet info
  Future<void> updateWallet(int id, {required String name, required String type}) async {
    await _dbService.updateWallet(id, {
      'name': name,
      'type': type,
    });
    await loadWallets();
  }

  /// Transfer balance between wallets
  Future<void> transferBalance({
    required int fromId,
    required int toId,
    required double amount,
  }) async {
    await _dbService.transferBalance(
      fromId: fromId,
      toId: toId,
      amount: amount,
    );
    await loadWallets();
  }

  /// Transfer all transactions from one wallet to another
  Future<void> transferTransactions({
    required int fromId,
    required int toId,
  }) async {
    await _dbService.transferTransactions(
      fromId: fromId,
      toId: toId,
    );
    await loadWallets();
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
