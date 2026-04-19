import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smooth_sheets/smooth_sheets.dart';
import 'package:easy_localization/easy_localization.dart';

import '../../../../core/services/database_service.dart';
import '../../../../features/wallet/presentation/providers/wallet_provider.dart';
import 'wallet_picker_sheet.dart';

class AddDebtPaymentSheet extends ConsumerStatefulWidget {
  final int debtId;
  final String direction;
  final VoidCallback onSaved;

  const AddDebtPaymentSheet({
    super.key,
    required this.debtId,
    required this.direction,
    required this.onSaved,
  });

  @override
  ConsumerState<AddDebtPaymentSheet> createState() => _AddDebtPaymentSheetState();
}

class _AddDebtPaymentSheetState extends ConsumerState<AddDebtPaymentSheet> {
  final _amountCtrl = TextEditingController();
  int? _selectedWalletId;

  Future<void> _submit() async {
    final amountText = _amountCtrl.text.trim();
    if (amountText.isEmpty || _selectedWalletId == null) return;
    
    final amount = double.tryParse(amountText);
    if (amount == null || amount <= 0) return;

    await DatabaseService().addDebtPayment(
      debtId: widget.debtId,
      amount: amount,
      direction: widget.direction,
      walletId: _selectedWalletId!,
    );

    if (mounted) {
      Navigator.pop(context);
      widget.onSaved();
    }
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final wallets = ref.watch(walletProvider);
    final title = widget.direction == 'plus'
        ? 'transaction.add_lent_payment'.tr()
        : 'transaction.add_borrowed_payment'.tr();

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
                    color: cs.onSurface.withValues(alpha: 0.2),
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
                        color: cs.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.handshake_rounded, color: cs.primary, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Text(
                      title,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                child: Column(
                  children: [
                    // AMOUNT
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.attach_money_rounded, color: cs.primary),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _amountCtrl,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(
                                hintText: '0.00',
                                border: InputBorder.none,
                                isDense: true,
                              ),
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // WALLET
                    GestureDetector(
                      onTap: () async {
                        final wallet = await showWalletPickerSheet(context, ref, selectedId: _selectedWalletId);
                        if (wallet != null) {
                          setState(() => _selectedWalletId = wallet.id);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: cs.primary.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.account_balance_wallet_rounded, color: cs.primary, size: 20),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('transaction.wallet'.tr(), style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                                  const SizedBox(height: 2),
                                  Text(
                                    _selectedWalletId == null 
                                      ? 'transaction.select_wallet'.tr() 
                                      : wallets.firstWhere((w) => w.id == _selectedWalletId, orElse: () => wallets.first).name,
                                    style: TextStyle(
                                      fontWeight: _selectedWalletId == null ? FontWeight.normal : FontWeight.bold,
                                      color: _selectedWalletId == null ? cs.onSurface.withValues(alpha: 0.5) : cs.onSurface,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(Icons.keyboard_arrow_down_rounded, color: cs.onSurface.withValues(alpha: 0.3)),
                          ],
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _submit,
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: Text(
                          'transaction.save_record'.tr(),
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
