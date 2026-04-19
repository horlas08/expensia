import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smooth_sheets/smooth_sheets.dart';
import 'package:animate_do/animate_do.dart';

import '../../../../features/wallet/domain/entities/wallet_entity.dart';
import '../../../../features/wallet/presentation/providers/wallet_provider.dart';
import '../../../../features/wallet/presentation/widgets/wallet_type_sheet.dart';
import '../../../../core/providers/currency_provider.dart';

// ---------------------------------------------------------------------------
// Router keys — dedicated nested navigator key for the wallet sheet
// ---------------------------------------------------------------------------
final _walletSheetNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'walletSheet',
);

void showWalletActionSheet(BuildContext context, WalletEntity wallet) {
  Navigator.of(context, rootNavigator: true).push(
    ModalSheetRoute<void>(
      swipeDismissible: true,
      builder: (context) => _WalletSheetShell(wallet: wallet),
    ),
  );
}

// ---------------------------------------------------------------------------
// Sheet shell — wraps the nested Navigator in a PagedSheet
// ---------------------------------------------------------------------------
class _WalletSheetShell extends StatefulWidget {
  const _WalletSheetShell({required this.wallet});
  final WalletEntity wallet;

  @override
  State<_WalletSheetShell> createState() => _WalletSheetShellState();
}

class _WalletSheetShellState extends State<_WalletSheetShell> {
  late final Map<String, WidgetBuilder> _routes;

  @override
  void initState() {
    super.initState();
    _routes = {
      '/': (_) => _WalletActionsRoot(wallet: widget.wallet),
      '/add-balance': (_) => _AmountFormPage(
            wallet: widget.wallet,
            actionType: _ActionType.addBalance,
          ),
      '/withdraw': (_) => _AmountFormPage(
            wallet: widget.wallet,
            actionType: _ActionType.withdraw,
          ),
      '/transfer-balance': (_) => _TransferBalancePage(wallet: widget.wallet),
      '/transfer-transactions': (_) =>
          _TransferTransactionsPage(wallet: widget.wallet),
      '/edit': (_) => _EditWalletPage(wallet: widget.wallet),
      '/delete': (_) => _DeleteWalletPage(wallet: widget.wallet),
    };
  }

  @override
  Widget build(BuildContext context) {
    final nestedNavigator = Navigator(
      key: _walletSheetNavigatorKey,
      initialRoute: '/',
      onGenerateRoute: (settings) {
        final builder = _routes[settings.name];
        if (builder == null) return null;
        return PagedSheetRoute<void>(
          settings: settings,
          builder: builder,
        );
      },
    );

    return PagedSheet(
      decoration: MaterialSheetDecoration(
        size: SheetSize.fit,
        clipBehavior: Clip.antiAlias,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        color: Theme.of(context).colorScheme.surface,
      ),
      navigator: nestedNavigator,
    );
  }
}

// ---------------------------------------------------------------------------
// Main Action Sheet content
// ---------------------------------------------------------------------------
class _WalletActionsRoot extends ConsumerWidget {
  const _WalletActionsRoot({required this.wallet});
  final WalletEntity wallet;

  void _navigate(String route) {
    _walletSheetNavigatorKey.currentState!.pushNamed(route);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final currencySymbol = ref.watch(currencySymbolProvider);

    return Container(
      color: cs.surface,
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
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
          const SizedBox(height: 16),

          // Header Card
          FadeInDown(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: _walletGradient(wallet.type),
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: _walletGradient(wallet.type).first.withValues(alpha: 0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ],
              ),
              child: Row(
                children: [
                   Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(_walletIcon(wallet.type), color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          wallet.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$currencySymbol${wallet.balance.toStringAsFixed(2)}',
                          style: const TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Actions list
          FadeInUp(
            delay: const Duration(milliseconds: 0),
            child: _ActionTile(
              icon: Icons.add_circle_rounded,
              title: 'common.add_balance'.tr(),
              subtitle: 'wallet.add_balance_desc'.tr(),
              iconColor: Colors.green,
              onTap: () => _navigate('/add-balance'),
            ),
          ),
          FadeInUp(
            delay: const Duration(milliseconds: 50),
            child: _ActionTile(
              icon: Icons.remove_circle_rounded,
              title: 'common.withdraw_balance'.tr(),
              subtitle: 'wallet.withdraw_balance_desc'.tr(),
              iconColor: Colors.red,
              onTap: () => _navigate('/withdraw'),
            ),
          ),
          FadeInUp(
            delay: const Duration(milliseconds: 100),
            child: _ActionTile(
              icon: Icons.swap_horiz_rounded,
              title: 'wallet.transfer'.tr(),
              subtitle: 'wallet.transfer_desc'.tr(),
              iconColor: Colors.blue,
              onTap: () => _navigate('/transfer-balance'),
            ),
          ),
          FadeInUp(
            delay: const Duration(milliseconds: 150),
            child: _ActionTile(
              icon: Icons.receipt_long_rounded,
              title: 'wallet.move_transactions'.tr(),
              subtitle: 'wallet.move_transactions_desc'.tr(),
              iconColor: Colors.purple,
              onTap: () => _navigate('/transfer-transactions'),
            ),
          ),
          FadeInUp(
            delay: const Duration(milliseconds: 200),
            child: _ActionTile(
              icon: Icons.edit_rounded,
              title: 'wallet.edit_wallet'.tr(),
              subtitle: 'wallet.edit_wallet_desc'.tr(),
              iconColor: Colors.orange,
              onTap: () => _navigate('/edit'),
            ),
          ),
          FadeInUp(
            delay: const Duration(milliseconds: 250),
            child: _ActionTile(
              icon: Icons.delete_rounded,
              title: 'wallet.delete_wallet'.tr(),
              subtitle: 'wallet.delete_wallet_desc_short'.tr(),
              iconColor: Colors.redAccent,
              onTap: () => _navigate('/delete'),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Reusable Action Tile
// ---------------------------------------------------------------------------
class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.iconColor,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color iconColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.transparent),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: cs.onSurface,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: cs.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: cs.onSurface.withValues(alpha: 0.2)),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared UI helper: nested sheet scaffold
// ---------------------------------------------------------------------------
class _NestedFormPageScaffold extends StatelessWidget {
  const _NestedFormPageScaffold({
    required this.title,
    required this.children,
    required this.accentColor,
  });

  final String title;
  final Color accentColor;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      color: cs.surface,
      padding: EdgeInsets.fromLTRB(24, 12, 24, MediaQuery.of(context).viewInsets.bottom + 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
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
          const SizedBox(height: 8),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded),
                onPressed: () => _walletSheetNavigatorKey.currentState?.pop(),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: accentColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Form Pages (Nested)
// ---------------------------------------------------------------------------

enum _ActionType { addBalance, withdraw }

class _AmountFormPage extends ConsumerStatefulWidget {
  const _AmountFormPage({required this.wallet, required this.actionType});
  final WalletEntity wallet;
  final _ActionType actionType;

  @override
  ConsumerState<_AmountFormPage> createState() => _AmountFormPageState();
}

class _AmountFormPageState extends ConsumerState<_AmountFormPage> {
  final _ctrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _ctrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final amount = double.tryParse(_ctrl.text.trim());
    if (amount == null || amount <= 0) return;

    setState(() => _loading = true);
    final notifier = ref.read(walletProvider.notifier);

    if (widget.actionType == _ActionType.addBalance) {
      notifier.addBalance(widget.wallet.id, amount);
    } else {
      notifier.withdrawBalance(widget.wallet.id, amount);
    }

    setState(() => _loading = false);
    _walletSheetNavigatorKey.currentState?.popUntil((r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final isAdd = widget.actionType == _ActionType.addBalance;
    final title =
        isAdd ? 'common.add_balance'.tr() : 'common.withdraw_balance'.tr();
    final color = isAdd ? Colors.green : Colors.red;

    return _NestedFormPageScaffold(
      title: title,
      accentColor: color,
      children: [
        TextField(
          controller: _ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: 'transaction.amount'.tr(),
            prefixIcon: const Icon(Icons.attach_money),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _noteCtrl,
          decoration: InputDecoration(
            labelText: 'transaction.note_hint'.tr(),
            prefixIcon: const Icon(Icons.notes),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 32),
        _SubmitButton(label: title, color: color, loading: _loading, onTap: _submit),
      ],
    );
  }
}

// --------------------------------------------------------------------------- //

class _TransferBalancePage extends ConsumerStatefulWidget {
  const _TransferBalancePage({required this.wallet});
  final WalletEntity wallet;

  @override
  ConsumerState<_TransferBalancePage> createState() => _TransferBalancePageState();
}

class _TransferBalancePageState extends ConsumerState<_TransferBalancePage> {
  WalletEntity? _toWallet;
  final _amountCtrl = TextEditingController();
  double? _convertedPreview;

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  void _onAmountChanged(String val) {
    final amount = double.tryParse(val);
    if (amount == null || _toWallet == null) {
      setState(() => _convertedPreview = null);
      return;
    }
    if (widget.wallet.rateToUsd != null &&
        _toWallet!.rateToUsd != null &&
        widget.wallet.currencyId != _toWallet!.currencyId) {
      setState(() {
        _convertedPreview = amount * (widget.wallet.rateToUsd! / _toWallet!.rateToUsd!);
      });
    } else {
      setState(() => _convertedPreview = null);
    }
  }

  void _submit() {
    final amount = double.tryParse(_amountCtrl.text.trim());
    if (amount == null || _toWallet == null) return;

    ref.read(walletProvider.notifier).transferBalance(
          fromId: widget.wallet.id,
          toId: _toWallet!.id,
          amount: amount,
        );
    _walletSheetNavigatorKey.currentState?.popUntil((r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final allWallets = ref.watch(walletProvider);
    final others = allWallets.where((w) => w.id != widget.wallet.id).toList();

    return _NestedFormPageScaffold(
      title: 'wallet.transfer_balance'.tr(),
      accentColor: Colors.blue,
      children: [
        TextField(
          controller: _amountCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: _onAmountChanged,
          decoration: InputDecoration(
            labelText: 'Amount',
            prefixIcon: const Icon(Icons.attach_money),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        if (_convertedPreview != null) ...[
          const SizedBox(height: 8),
          Text(
            '≈ ${_convertedPreview!.toStringAsFixed(2)} ${_toWallet?.currencyCode ?? ''}',
            style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
          ),
        ],
        const SizedBox(height: 16),
        DropdownButtonFormField<WalletEntity>(
          initialValue: _toWallet,
          decoration: InputDecoration(
            labelText: 'wallet.to_wallet'.tr(),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          items: others
              .map((w) => DropdownMenuItem(
                    value: w,
                    child: Row(children: [
                      Icon(_walletIcon(w.type), size: 20),
                      const SizedBox(width: 8),
                      Text(w.name),
                    ]),
                  ))
              .toList(),
          onChanged: (val) => setState(() => _toWallet = val),
        ),
        const SizedBox(height: 32),
        _SubmitButton(label: 'wallet.transfer'.tr(), color: Colors.blue, loading: false, onTap: _submit),
      ],
    );
  }
}

// --------------------------------------------------------------------------- //

class _TransferTransactionsPage extends ConsumerStatefulWidget {
  const _TransferTransactionsPage({required this.wallet});
  final WalletEntity wallet;

  @override
  ConsumerState<_TransferTransactionsPage> createState() => _TransferTransactionsPageState();
}

class _TransferTransactionsPageState extends ConsumerState<_TransferTransactionsPage> {
  WalletEntity? _toWallet;

  void _submit() {
    if (_toWallet == null) return;
    ref.read(walletProvider.notifier).transferTransactions(
          fromId: widget.wallet.id,
          toId: _toWallet!.id,
        );
    _walletSheetNavigatorKey.currentState?.popUntil((r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final allWallets = ref.watch(walletProvider);
    final others = allWallets.where((w) => w.id != widget.wallet.id).toList();

    return _NestedFormPageScaffold(
      title: 'wallet.move_transactions'.tr(),
      accentColor: Colors.purple,
      children: [
        DropdownButtonFormField<WalletEntity>(
          initialValue: _toWallet,
          decoration: InputDecoration(
            labelText: 'wallet.destination_wallet'.tr(),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          items: others
              .map((w) => DropdownMenuItem(
                    value: w,
                    child: Row(children: [
                      Icon(_walletIcon(w.type), size: 20),
                      const SizedBox(width: 8),
                      Text(w.name),
                    ]),
                  ))
              .toList(),
          onChanged: (val) => setState(() => _toWallet = val),
        ),
        const SizedBox(height: 32),
        _SubmitButton(label: 'wallet.move_transactions'.tr(), color: Colors.purple, loading: false, onTap: _submit),
      ],
    );
  }
}

// --------------------------------------------------------------------------- //

class _EditWalletPage extends ConsumerStatefulWidget {
  const _EditWalletPage({required this.wallet});
  final WalletEntity wallet;

  @override
  ConsumerState<_EditWalletPage> createState() => _EditWalletPageState();
}

class _EditWalletPageState extends ConsumerState<_EditWalletPage> {
  late final TextEditingController _nameCtrl;
  late String _type;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.wallet.name);
    _type = widget.wallet.type;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;

    ref.read(walletProvider.notifier).updateWallet(
          widget.wallet.id,
          name: name,
          type: _type,
        );
    _walletSheetNavigatorKey.currentState?.popUntil((r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return _NestedFormPageScaffold(
      title: 'wallet.edit_wallet'.tr(),
      accentColor: Colors.orange,
      children: [
        TextField(
          controller: _nameCtrl,
          decoration: InputDecoration(
            labelText: 'wallet.wallet_name'.tr(),
            prefixIcon: const Icon(Icons.wallet),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: () async {
            final newType = await showWalletTypeSheet(context, _type);
            if (newType != null) {
              setState(() => _type = newType);
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              border: Border.all(color: Theme.of(context).colorScheme.outline),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Text('wallet.wallet_type'.tr(), style: const TextStyle(fontSize: 16)),
                const Spacer(),
                Text(
                  _type.toUpperCase(),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.arrow_drop_down_rounded),
              ],
            ),
          ),
        ),
        const SizedBox(height: 32),
        _SubmitButton(label: 'common.save'.tr(), color: Colors.orange, loading: false, onTap: _submit),
      ],
    );
  }
}

// --------------------------------------------------------------------------- //

class _DeleteWalletPage extends ConsumerStatefulWidget {
  const _DeleteWalletPage({required this.wallet});
  final WalletEntity wallet;

  @override
  ConsumerState<_DeleteWalletPage> createState() => _DeleteWalletPageState();
}

class _DeleteWalletPageState extends ConsumerState<_DeleteWalletPage> {
  void _submit() {
    ref.read(walletProvider.notifier).deleteWallet(widget.wallet.id);
    _walletSheetNavigatorKey.currentState?.popUntil((r) => r.isFirst);
    // Finally close the whole sheet
    Navigator.of(context, rootNavigator: true).pop();
  }

  @override
  Widget build(BuildContext context) {
    return _NestedFormPageScaffold(
      title: 'wallet.delete_wallet'.tr(),
      accentColor: Colors.redAccent,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.red.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.red),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'wallet.delete_wallet_desc'.tr(),
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'wallet.delete_irreversible'.tr(),
          style: const TextStyle(fontSize: 14),
        ),
        const SizedBox(height: 32),
        _SubmitButton(label: 'wallet.delete_permanently'.tr(), color: Colors.redAccent, loading: false, onTap: _submit),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

class _SubmitButton extends StatelessWidget {
  const _SubmitButton({
    required this.label,
    required this.color,
    required this.loading,
    required this.onTap,
  });

  final String label;
  final Color color;
  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: loading ? null : onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 4,
        ),
        child: loading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      ),
    );
  }
}

List<Color> _walletGradient(String type) {
  switch (type.toLowerCase()) {
    case 'cash':
      return [const Color(0xFF1A1A2E), const Color(0xFF16213E)];
    case 'bank':
      return [const Color(0xFF5C35CC), const Color(0xFF9B59B6)];
    case 'investment':
      return [const Color(0xFFE65C00), const Color(0xFFF9D423)];
    case 'credit_card':
      return [const Color(0xFFC70039), const Color(0xFF900C3F)];
    default:
      return [const Color(0xFF2C3E50), const Color(0xFF4CA1AF)];
  }
}

IconData _walletIcon(String type) {
  switch (type.toLowerCase()) {
    case 'cash':
      return Icons.money;
    case 'bank':
      return Icons.account_balance;
    case 'investment':
      return Icons.trending_up;
    case 'credit_card':
      return Icons.credit_card_rounded;
    default:
      return Icons.wallet;
  }
}
