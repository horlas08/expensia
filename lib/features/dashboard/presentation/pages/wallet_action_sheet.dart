import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:smooth_sheets/smooth_sheets.dart';
import 'package:animate_do/animate_do.dart';

import '../../../../features/wallet/domain/entities/wallet_entity.dart';
import '../../../../features/wallet/presentation/providers/wallet_provider.dart';

// ---------------------------------------------------------------------------
// Router keys — dedicated nested navigator key for the wallet sheet
// ---------------------------------------------------------------------------
final _walletSheetNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'walletSheet',
);

// ---------------------------------------------------------------------------
// Public API — shows the wallet action sheet via GoRouter ShellRoute
// ---------------------------------------------------------------------------

/// Call this from the WalletPage when a card is tapped.
///
/// Uses a [ModalSheetRoute] with a dedicated [GoRouter] ShellRoute–like
/// nested [Navigator] inside [PagedSheet], exactly as the official example.
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
          scrollConfiguration: const SheetScrollConfiguration(),
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
// Root page — action grid (matches old OptionsBottomSheetWidget)
// ---------------------------------------------------------------------------
class _WalletActionsRoot extends StatelessWidget {
  const _WalletActionsRoot({required this.wallet});
  final WalletEntity wallet;

  void _navigate(BuildContext context, String route) {
    _walletSheetNavigatorKey.currentState!.pushNamed(route);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

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

          // Title row
          Row(
            children: [
              CircleAvatar(
                backgroundColor: _walletColor(wallet.type).withValues(alpha: 0.15),
                child: Icon(_walletIcon(wallet.type), color: _walletColor(wallet.type)),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    wallet.name,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '${wallet.currencySymbol ?? '\$'}${wallet.balance.toStringAsFixed(2)}',
                    style: TextStyle(color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Financial Actions label
          Text('Financial Actions',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: cs.primary)),
          const SizedBox(height: 12),

          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 3,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            children: [
              FadeInUp(
                delay: const Duration(milliseconds: 0),
                child: _ActionTile(
                  icon: Icons.add_circle_outline,
                  label: 'Add Balance',
                  color: Colors.green,
                  onTap: () => _navigate(context, '/add-balance'),
                ),
              ),
              FadeInUp(
                delay: const Duration(milliseconds: 60),
                child: _ActionTile(
                  icon: Icons.remove_circle_outline,
                  label: 'Withdraw',
                  color: Colors.red,
                  onTap: () => _navigate(context, '/withdraw'),
                ),
              ),
              FadeInUp(
                delay: const Duration(milliseconds: 120),
                child: _ActionTile(
                  icon: Icons.swap_horiz,
                  label: 'Transfer',
                  color: Colors.blue,
                  onTap: () => _navigate(context, '/transfer-balance'),
                ),
              ),
              FadeInUp(
                delay: const Duration(milliseconds: 180),
                child: _ActionTile(
                  icon: Icons.receipt_long,
                  label: 'Move Txns',
                  color: Colors.purple,
                  onTap: () => _navigate(context, '/transfer-transactions'),
                ),
              ),
              FadeInUp(
                delay: const Duration(milliseconds: 240),
                child: _ActionTile(
                  icon: Icons.edit_outlined,
                  label: 'Edit',
                  color: Colors.orange,
                  onTap: () => _navigate(context, '/edit'),
                ),
              ),
              FadeInUp(
                delay: const Duration(milliseconds: 300),
                child: _ActionTile(
                  icon: Icons.delete_outline,
                  label: 'Delete',
                  color: Colors.redAccent,
                  onTap: () => _navigate(context, '/delete'),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Add Balance / Withdraw page
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
    // Pop back to root
    _walletSheetNavigatorKey.currentState?.popUntil((r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final isAdd = widget.actionType == _ActionType.addBalance;
    final title = isAdd ? 'Add Balance' : 'Withdraw';
    final color = isAdd ? Colors.green : Colors.red;

    return _FormSheetScaffold(
      title: title,
      accentColor: color,
      children: [
        _AmountField(controller: _ctrl),
        const SizedBox(height: 16),
        _NoteField(controller: _noteCtrl),
        const SizedBox(height: 32),
        _SubmitButton(
          label: title,
          color: color,
          loading: _loading,
          onTap: _submit,
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Transfer Balance page (mirroring TransferBalanceWidget)
// ---------------------------------------------------------------------------
class _TransferBalancePage extends ConsumerStatefulWidget {
  const _TransferBalancePage({required this.wallet});
  final WalletEntity wallet;

  @override
  ConsumerState<_TransferBalancePage> createState() =>
      _TransferBalancePageState();
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
        _convertedPreview =
            amount * (widget.wallet.rateToUsd! / _toWallet!.rateToUsd!);
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

    return _FormSheetScaffold(
      title: 'Transfer Balance',
      accentColor: Colors.blue,
      children: [
        _AmountField(controller: _amountCtrl, onChanged: _onAmountChanged),
        if (_convertedPreview != null) ...[
          const SizedBox(height: 8),
          Text(
            '≈ ${_convertedPreview!.toStringAsFixed(2)} ${_toWallet?.currencyCode ?? ''}',
            style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
          ),
        ],
        const SizedBox(height: 16),
        // Destination selector
        DropdownButtonFormField<WalletEntity>(
          initialValue: _toWallet,
          decoration: InputDecoration(
            labelText: 'To Wallet',
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
        _SubmitButton(
          label: 'Transfer',
          color: Colors.blue,
          loading: false,
          onTap: _submit,
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Transfer Transactions page (mirroring TransferTransactionWidget)
// ---------------------------------------------------------------------------
class _TransferTransactionsPage extends ConsumerStatefulWidget {
  const _TransferTransactionsPage({required this.wallet});
  final WalletEntity wallet;

  @override
  ConsumerState<_TransferTransactionsPage> createState() =>
      _TransferTransactionsPageState();
}

class _TransferTransactionsPageState
    extends ConsumerState<_TransferTransactionsPage> {
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

    return _FormSheetScaffold(
      title: 'Move All Transactions',
      accentColor: Colors.purple,
      children: [
        DropdownButtonFormField<WalletEntity>(
          initialValue: _toWallet,
          decoration: InputDecoration(
            labelText: 'Destination Wallet',
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
        _SubmitButton(
          label: 'Move Transactions',
          color: Colors.purple,
          loading: false,
          onTap: _submit,
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Edit Wallet page
// ---------------------------------------------------------------------------
class _EditWalletPage extends ConsumerStatefulWidget {
  const _EditWalletPage({required this.wallet});
  final WalletEntity wallet;

  @override
  ConsumerState<_EditWalletPage> createState() => _EditWalletPageState();
}

class _EditWalletPageState extends ConsumerState<_EditWalletPage> {
  late final TextEditingController _nameCtrl;
  late String _selectedType;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.wallet.name);
    _selectedType = widget.wallet.type;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    ref.read(walletProvider.notifier).updateWallet(
          widget.wallet.id,
          name: _nameCtrl.text.trim(),
          type: _selectedType,
        );
    _walletSheetNavigatorKey.currentState?.popUntil((r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return _FormSheetScaffold(
      title: 'Edit Wallet',
      accentColor: Colors.orange,
      children: [
        TextField(
          controller: _nameCtrl,
          decoration: InputDecoration(
            labelText: 'Wallet Name',
            prefixIcon: const Icon(Icons.wallet),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          initialValue: _selectedType,
          decoration: InputDecoration(
            labelText: 'Wallet Type',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          items: const [
            DropdownMenuItem(value: 'cash', child: Text('💵 Cash')),
            DropdownMenuItem(value: 'bank', child: Text('🏦 Bank')),
            DropdownMenuItem(value: 'investment', child: Text('📈 Investment')),
            DropdownMenuItem(value: 'other', child: Text('🗂 Other')),
          ],
          onChanged: (val) => setState(() => _selectedType = val!),
        ),
        const SizedBox(height: 32),
        _SubmitButton(
          label: 'Save Changes',
          color: Colors.orange,
          loading: false,
          onTap: _submit,
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Delete Wallet page (confirmation)
// ---------------------------------------------------------------------------
class _DeleteWalletPage extends ConsumerWidget {
  const _DeleteWalletPage({required this.wallet});
  final WalletEntity wallet;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _FormSheetScaffold(
      title: 'Delete Wallet',
      accentColor: Colors.red,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.red.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Are you sure you want to delete "${wallet.name}"? '
                  'This action cannot be undone.',
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        _SubmitButton(
          label: 'Yes, Delete',
          color: Colors.red,
          loading: false,
          onTap: () {
            ref.read(walletProvider.notifier).deleteWallet(wallet.id);
            // Pop the whole modal sheet
            Navigator.of(context, rootNavigator: true).pop();
          },
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () =>
                _walletSheetNavigatorKey.currentState?.popUntil((r) => r.isFirst),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Cancel'),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Shared UI helpers
// ---------------------------------------------------------------------------

/// Consistent sheet page scaffold with back button + title
class _FormSheetScaffold extends StatelessWidget {
  const _FormSheetScaffold({
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
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
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
              Text(
                title,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: accentColor,
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

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cs.outlineVariant),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }
}

class _AmountField extends StatelessWidget {
  const _AmountField({required this.controller, this.onChanged});
  final TextEditingController controller;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: 'Amount',
        prefixIcon: const Icon(Icons.attach_money),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

class _NoteField extends StatelessWidget {
  const _NoteField({required this.controller});
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: 'Note (optional)',
        prefixIcon: const Icon(Icons.notes),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

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
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 4,
        ),
        child: loading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white))
            : Text(label,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Utility helpers
// ---------------------------------------------------------------------------
Color _walletColor(String type) {
  switch (type.toLowerCase()) {
    case 'cash':
      return Colors.green;
    case 'bank':
      return Colors.blue;
    case 'investment':
      return Colors.orange;
    default:
      return Colors.grey;
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
    default:
      return Icons.wallet;
  }
}
