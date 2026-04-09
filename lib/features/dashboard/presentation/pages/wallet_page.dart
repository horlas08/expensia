import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:animate_do/animate_do.dart';

import '../../../../features/wallet/domain/entities/wallet_entity.dart';
import '../../../../features/wallet/presentation/providers/wallet_provider.dart';
import '../../../../features/dashboard/presentation/pages/wallet_action_sheet.dart';

class WalletPage extends ConsumerStatefulWidget {
  const WalletPage({super.key});

  @override
  ConsumerState<WalletPage> createState() => _WalletPageState();
}

class _WalletPageState extends ConsumerState<WalletPage> {
  final PageController _pageController =
      PageController(viewportFraction: 0.88);
  double _currentPageValue = 0.0;

  @override
  void initState() {
    super.initState();
    _pageController.addListener(() {
      setState(() => _currentPageValue = _pageController.page ?? 0.0);
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final wallets = ref.watch(walletProvider);
    final totalBalance = ref.watch(totalBalanceProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Wallets',
            style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddWalletSheet(context),
          ),
        ],
      ),
      body: wallets.isEmpty
          ? _EmptyWallets(onAdd: () => _showAddWalletSheet(context))
          : Column(
              children: [
                // ----- Total balance strip -----
                FadeInDown(
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Theme.of(context).colorScheme.primary,
                          Colors.deepPurple
                        ],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(context)
                              .colorScheme
                              .primary
                              .withValues(alpha: 0.25),
                          blurRadius: 16,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Total Balance',
                                style: TextStyle(
                                    color: Colors.white70, fontSize: 13)),
                            const SizedBox(height: 4),
                            Text(
                              '\$${totalBalance.toStringAsFixed(2)}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          '${wallets.length} wallet${wallets.length == 1 ? '' : 's'}',
                          style: const TextStyle(
                              color: Colors.white60, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // ----- Wallet card carousel -----
                SizedBox(
                  height: 220,
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: wallets.length,
                    itemBuilder: (context, index) {
                      final wallet = wallets[index];
                      final diff =
                          (index - _currentPageValue).abs().clamp(0.0, 1.0);
                      final scale = 1.0 - diff * 0.08;

                      return Transform.scale(
                        scale: scale,
                        child: FadeInRight(
                          delay: Duration(milliseconds: 80 * index),
                          child: GestureDetector(
                            onTap: () =>
                                showWalletActionSheet(context, wallet),
                            child: _WalletCard(wallet: wallet),
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // ----- Page indicator -----
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    wallets.length,
                    (i) => AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      height: 6,
                      width: i == _currentPageValue.round() ? 20 : 6,
                      decoration: BoxDecoration(
                        color: i == _currentPageValue.round()
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 32),
                // ----- Quick action hint -----
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    'Tap a card to view actions',
                    style: TextStyle(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.4),
                        fontSize: 13),
                  ),
                ),
              ],
            ),
    );
  }

  void _showAddWalletSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddWalletSheet(
        onAdd: (wallet) => ref.read(walletProvider.notifier).addWallet(wallet),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Individual wallet card
// ---------------------------------------------------------------------------
class _WalletCard extends StatelessWidget {
  const _WalletCard({required this.wallet});
  final WalletEntity wallet;

  @override
  Widget build(BuildContext context) {
    final colors = _gradientFor(wallet.type);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: colors.first.withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Top row — type + lock/hide icons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(_iconFor(wallet.type), color: Colors.white, size: 28),
                  const SizedBox(width: 10),
                  Text(
                    wallet.type.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  if ((wallet.bloc ?? 0) == 1)
                    const Icon(Icons.lock, color: Colors.white70, size: 18),
                  const SizedBox(width: 4),
                  if ((wallet.hide ?? 0) == 1)
                    const Icon(Icons.visibility_off,
                        color: Colors.white70, size: 18),
                  const Icon(Icons.more_horiz, color: Colors.white70, size: 20),
                ],
              ),
            ],
          ),

          // Bottom — balance + name
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                wallet.name,
                style: const TextStyle(color: Colors.white60, fontSize: 13),
              ),
              const SizedBox(height: 4),
              Text(
                (wallet.hide ?? 0) == 1
                    ? '••••••'
                    : '${wallet.currencySymbol ?? '\$'}${wallet.balance.toStringAsFixed(2)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Color> _gradientFor(String type) {
    switch (type.toLowerCase()) {
      case 'cash':
        return [const Color(0xFF1A1A2E), const Color(0xFF16213E)]; // dark/black
      case 'bank':
        return [const Color(0xFF5C35CC), const Color(0xFF9B59B6)];
      case 'investment':
        return [const Color(0xFFE65C00), const Color(0xFFF9D423)];
      default:
        return [const Color(0xFF2C3E50), const Color(0xFF4CA1AF)];
    }
  }

  IconData _iconFor(String type) {
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
}

// ---------------------------------------------------------------------------
// Empty state
// ---------------------------------------------------------------------------
class _EmptyWallets extends StatelessWidget {
  const _EmptyWallets({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.account_balance_wallet_outlined,
              size: 80,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.2)),
          const SizedBox(height: 16),
          Text('No wallets yet',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.4))),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: const Text('Add Wallet'),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Add new wallet sheet
// ---------------------------------------------------------------------------
class _AddWalletSheet extends StatefulWidget {
  const _AddWalletSheet({required this.onAdd});
  final ValueChanged<WalletEntity> onAdd;

  @override
  State<_AddWalletSheet> createState() => _AddWalletSheetState();
}

class _AddWalletSheetState extends State<_AddWalletSheet> {
  final _nameCtrl = TextEditingController();
  final _balanceCtrl = TextEditingController();
  String _type = 'cash';
  static int _nextId = 100; // offset from seed data

  @override
  void dispose() {
    _nameCtrl.dispose();
    _balanceCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameCtrl.text.trim();
    final balance = double.tryParse(_balanceCtrl.text.trim()) ?? 0;
    if (name.isEmpty) return;

    widget.onAdd(WalletEntity(
      id: _nextId++,
      name: name,
      type: _type,
      balance: balance,
      currencyCode: 'USD',
      currencySymbol: '\$',
      currencyNameEn: 'US Dollar',
      rateToUsd: 1.0,
    ));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Add New Wallet',
              style:
                  TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          TextField(
            controller: _nameCtrl,
            decoration: InputDecoration(
              labelText: 'Wallet Name',
              prefixIcon: const Icon(Icons.wallet),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _balanceCtrl,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Initial Balance',
              prefixIcon: const Icon(Icons.attach_money),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _type,
            decoration: InputDecoration(
              labelText: 'Type',
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            items: const [
              DropdownMenuItem(value: 'cash', child: Text('💵 Cash')),
              DropdownMenuItem(value: 'bank', child: Text('🏦 Bank')),
              DropdownMenuItem(
                  value: 'investment',
                  child: Text('📈 Investment')),
              DropdownMenuItem(value: 'other', child: Text('🗂 Other')),
            ],
            onChanged: (val) => setState(() => _type = val!),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _submit,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Create Wallet',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }
}
