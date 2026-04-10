import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../../features/transactions/presentation/pages/add_income_expense_page.dart';
import '../../../../features/transactions/presentation/pages/add_debt_page.dart';
import '../../../../features/transactions/presentation/pages/add_installment_page.dart';
import '../../../../features/transactions/presentation/pages/add_transfer_page.dart';

// ---------------------------------------------------------------------------
// TransactionTypeSheet — matches the old CustomActionBottomSheet (4 types)
// ---------------------------------------------------------------------------
Future<void> showTransactionTypeSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const TransactionTypeSheet(),
  );
}

class TransactionTypeSheet extends ConsumerWidget {
  const TransactionTypeSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;

    final options = [
      _TypeOption(
        icon: Icons.arrow_downward_rounded,
        iconBg: const Color(0xFF00C48C),
        label: 'transaction.type_income'.tr(),
        subtitle: 'transaction.type_income_sub'.tr(),
        onTap: () {
          Navigator.of(context).pop();
          Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => const AddIncomeExpensePage(transactionType: 'income'),
          ));
        },
      ),
      _TypeOption(
        icon: Icons.arrow_upward_rounded,
        iconBg: const Color(0xFFFF4757),
        label: 'transaction.type_expense'.tr(),
        subtitle: 'transaction.type_expense_sub'.tr(),
        onTap: () {
          Navigator.of(context).pop();
          Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => const AddIncomeExpensePage(transactionType: 'expense'),
          ));
        },
      ),
      _TypeOption(
        icon: Icons.handshake_outlined,
        iconBg: const Color(0xFF6B4EFF),
        label: 'transaction.type_debt'.tr(),
        subtitle: 'transaction.type_debt_sub'.tr(),
        onTap: () {
          Navigator.of(context).pop();
          Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => const AddDebtPage(),
          ));
        },
      ),
      _TypeOption(
        icon: Icons.credit_card_rounded,
        iconBg: const Color(0xFFFFBE0B),
        label: 'transaction.type_installment'.tr(),
        subtitle: 'transaction.type_installment_sub'.tr(),
        onTap: () {
          Navigator.of(context).pop();
          Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => const AddInstallmentPage(),
          ));
        },
      ),
      _TypeOption(
        icon: Icons.swap_horiz_rounded,
        iconBg: const Color(0xFF3498DB),
        label: 'transaction.type_transfer'.tr(),
        subtitle: 'transaction.type_transfer_sub'.tr(),
        onTap: () {
          Navigator.of(context).pop();
          Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => const AddTransferPage(),
          ));
        },
      ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
          const SizedBox(height: 20),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [cs.primary, Colors.deepPurple],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.add_rounded, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                'transaction.add'.tr(),
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: cs.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'transaction.add_sub'.tr(),
            style: TextStyle(
              fontSize: 13,
              color: cs.onSurface.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 24),
          ...options.map((opt) => _TypeTile(option: opt, cs: cs)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Data model
// ---------------------------------------------------------------------------
class _TypeOption {
  const _TypeOption({
    required this.icon,
    required this.iconBg,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final Color iconBg;
  final String label;
  final String subtitle;
  final VoidCallback onTap;
}

// ---------------------------------------------------------------------------
// Individual tile
// ---------------------------------------------------------------------------
class _TypeTile extends StatelessWidget {
  const _TypeTile({required this.option, required this.cs});
  final _TypeOption option;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        borderRadius: BorderRadius.circular(16),
        color: cs.surfaceContainerLow,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: option.onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: option.iconBg,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: option.iconBg.withValues(alpha: 0.35),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(option.icon, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        option.label,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: cs.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        option.subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: cs.onSurface.withValues(alpha: 0.35),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
