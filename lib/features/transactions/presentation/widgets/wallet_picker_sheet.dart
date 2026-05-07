import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:animate_do/animate_do.dart';
import 'package:smooth_sheets/smooth_sheets.dart';
import '../../../../features/wallet/domain/entities/wallet_entity.dart';
import '../../../../features/wallet/presentation/providers/wallet_provider.dart';
import '../../../../features/wallet/presentation/utils/wallet_localization.dart';
import '../../../../core/providers/currency_provider.dart';

Future<WalletEntity?> showWalletPickerSheet(BuildContext context, WidgetRef ref, {int? selectedId}) {
  return Navigator.push<WalletEntity?>(
    context,
    ModalSheetRoute(
      builder: (_) => WalletPickerSheet(selectedId: selectedId),
    ),
  );
}

class WalletPickerSheet extends ConsumerWidget {
  const WalletPickerSheet({super.key, this.selectedId});
  final int? selectedId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final wallets = ref.watch(walletProvider);
    final currentCurrencySymbol = ref.watch(currencySymbolProvider);

    return Sheet(
      initialOffset: const SheetOffset(1.0),
      snapGrid: const SheetSnapGrid.stepless(),
      child: SheetContentScaffold(
        body: Container(
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: cs.onSurface.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: cs.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.account_balance_wallet_rounded, color: cs.primary, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Text(
                      'transaction.select_wallet'.tr(),
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              if (wallets.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 48),
                  child: Column(
                    children: [
                      Icon(Icons.wallet_rounded, size: 48, color: cs.onSurface.withOpacity(0.2)),
                      const SizedBox(height: 16),
                      Text(
                        'transaction.no_wallet'.tr(),
                        style: TextStyle(color: cs.onSurface.withOpacity(0.5)),
                      ),
                    ],
                  ),
                )
              else
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    itemCount: wallets.length,
                    itemBuilder: (context, index) {
                      final wallet = wallets[index];
                      final isSelected = wallet.id == selectedId;
                      
                      return FadeInUp(
                        duration: Duration(milliseconds: 300 + (index * 50)),
                        child: GestureDetector(
                          onTap: () => Navigator.of(context).pop(wallet),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: isSelected ? cs.primary.withOpacity(0.08) : cs.surfaceContainerLow,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isSelected ? cs.primary : Colors.transparent,
                                width: 2,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: _walletColor(wallet.type).withOpacity(0.12),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    _walletIcon(wallet.type),
                                    color: _walletColor(wallet.type),
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        wallet.displayName(context),
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        _walletTypeLabel(wallet.type),
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: cs.onSurface.withOpacity(0.5),
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      // '$currentCurrencySymbol${wallet.balance.toStringAsFixed(2)}',
                                      '${wallet.balance.toStringAsFixed(2)}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: wallet.balance >= 0 ? const Color(0xFF00C48C) : const Color(0xFFFF4757),
                                      ),
                                    ),
                                    if (isSelected)
                                      Icon(Icons.check_circle_rounded, color: cs.primary, size: 16),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _walletIcon(String type) {
    switch (type.toLowerCase()) {
      case 'cash':
        return Icons.money_rounded;
      case 'bank':
        return Icons.account_balance_rounded;
      case 'investment':
        return Icons.trending_up_rounded;
      default:
        return Icons.wallet_rounded;
    }
  }

  Color _walletColor(String type) {
    switch (type.toLowerCase()) {
      case 'cash':
        return const Color(0xFF00C48C);
      case 'bank':
        return const Color(0xFF42A5F5);
      case 'investment':
        return const Color(0xFFFFA726);
      default:
        return const Color(0xFF9CCC65);
    }
  }

  String _walletTypeLabel(String type) {
    switch (type.toLowerCase()) {
      case 'cash':
        return 'wallet.cash'.tr();
      case 'bank':
        return 'wallet.bank'.tr();
      case 'investment':
        return 'wallet.investment'.tr();
      case 'credit_card':
        return 'wallet.credit_card'.tr();
      default:
        return 'wallet.other'.tr();
    }
  }
}
