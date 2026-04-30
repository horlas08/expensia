import 'package:flutter/material.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:animate_do/animate_do.dart';

import '../../../../features/wallet/domain/entities/wallet_entity.dart';
import '../../../../features/wallet/presentation/providers/wallet_provider.dart';
import '../../../../features/dashboard/presentation/pages/wallet_action_sheet.dart';
import '../../../../core/providers/currency_provider.dart';
import '../../../../features/wallet/presentation/utils/wallet_localization.dart';
import '../../../../features/wallet/presentation/widgets/wallet_type_sheet.dart';

class WalletPage extends ConsumerStatefulWidget {
  const WalletPage({super.key});

  @override
  ConsumerState<WalletPage> createState() => _WalletPageState();
}

class _WalletPageState extends ConsumerState<WalletPage> {
  final PageController _pageController = PageController(viewportFraction: 0.88);
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
    final currencySymbol = ref.watch(currencySymbolProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'wallet.my_wallets'.tr(),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: () => _showAddWalletSheet(context),
            child: Row(
              children: [
                Text(
                  'wallet.add_wallet'.tr(),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.add, size: 20),
              ],
            ),
          ),
        ],
      ),
      body:
          wallets.isEmpty
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
                            Colors.deepPurple,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Theme.of(
                              context,
                            ).colorScheme.primary.withValues(alpha: 0.25),
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
                              Text(
                                'wallet.total_balance'.tr(),
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 4),
                              _WalletAmountText(
                                amount: totalBalance.toStringAsFixed(2),
                                currencySymbol: currencySymbol,
                                amountStyle: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            'wallet.wallet_count'.tr(args: ['${wallets.length}']),
                            style: const TextStyle(
                              color: Colors.white60,
                              fontSize: 13,
                            ),
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
                        final diff = (index - _currentPageValue).abs().clamp(
                          0.0,
                          1.0,
                        );
                        final scale = 1.0 - diff * 0.08;

                        return Transform.scale(
                          scale: scale,
                          child: FadeInRight(
                            delay: Duration(milliseconds: 80 * index),
                            child: GestureDetector(
                              onTap:
                                  () => showWalletActionSheet(context, wallet),
                              child: _WalletCard(
                                wallet: wallet,
                                currencySymbol: currencySymbol,
                              ),
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
                          color:
                              i == _currentPageValue.round()
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context).colorScheme.onSurface
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
                      'wallet.tap_card_actions'.tr(),
                      style: TextStyle(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.4),
                        fontSize: 13,
                      ),
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
      builder:
          (_) => _AddWalletSheet(
            onAdd:
                (wallet) => ref.read(walletProvider.notifier).addWallet(wallet),
          ),
    );
  }
}

// ---------------------------------------------------------------------------
// Individual wallet card
// ---------------------------------------------------------------------------
class _WalletCard extends StatelessWidget {
  const _WalletCard({required this.wallet, required this.currencySymbol});
  final WalletEntity wallet;
  final String currencySymbol;

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
                    _localizedWalletType(context, wallet.type),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
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
                    const Icon(
                      Icons.visibility_off,
                      color: Colors.white70,
                      size: 18,
                    ),
                  const Icon(Icons.more_horiz, color: Colors.white70, size: 20),
                ],
              ),
            ],
          ),

          // Bottom — balance + name
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AutoSizeText(
                wallet.displayName(context),
                maxLines: 1,
                minFontSize: 10,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white60, fontSize: 13),
              ),
              const SizedBox(height: 4),
              _WalletAmountText(
                amount:
                    (wallet.hide ?? 0) == 1
                        ? '••••••'
                        : wallet.balance.toStringAsFixed(2),
                currencySymbol: currencySymbol,
                showCurrency: (wallet.hide ?? 0) != 1,
                amountStyle: const TextStyle(
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
      case 'credit_card':
        return [const Color(0xFFC70039), const Color(0xFF900C3F)];
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
      case 'credit_card':
        return Icons.credit_card_rounded;
      default:
        return Icons.wallet;
    }
  }

  String _localizedWalletType(BuildContext context, String type) {
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

class _WalletAmountText extends StatelessWidget {
  const _WalletAmountText({
    required this.amount,
    required this.currencySymbol,
    this.showCurrency = true,
    this.amountStyle = const TextStyle(
      color: Colors.white,
      fontSize: 28,
      fontWeight: FontWeight.bold,
    ),
  });

  final String amount;
  final String currencySymbol;
  final bool showCurrency;
  final TextStyle amountStyle;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showCurrency) ...[
          Padding(
            padding: const EdgeInsets.only(top: 4, right: 4),
            child: Text(
              currencySymbol,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
        Flexible(
          child: AutoSizeText(
            amount,
            maxLines: 1,
            minFontSize: 10,
            overflow: TextOverflow.ellipsis,
            style: amountStyle,
          ),
        ),
      ],
    );
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
          Icon(
            Icons.account_balance_wallet_outlined,
            size: 80,
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.2),
          ),
          const SizedBox(height: 16),
          Text(
            'wallet.no_wallets_yet'.tr(),
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.4),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: onAdd,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('wallet.add_wallet'.tr(), style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                const Icon(Icons.add, size: 18),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Add new wallet sheet — ConsumerStatefulWidget to access currency provider
// ---------------------------------------------------------------------------
class _AddWalletSheet extends ConsumerStatefulWidget {
  const _AddWalletSheet({required this.onAdd});
  final ValueChanged<WalletEntity> onAdd;

  @override
  ConsumerState<_AddWalletSheet> createState() => _AddWalletSheetState();
}

class _AddWalletSheetState extends ConsumerState<_AddWalletSheet> {
  final _nameCtrl = TextEditingController();
  final _balanceCtrl = TextEditingController();
  String _type = 'cash';
  String? _nameError;
  String? _balanceError;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _balanceCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameCtrl.text.trim();
    final balanceText = _balanceCtrl.text.trim();
    final balance = double.tryParse(balanceText);

    setState(() {
      _nameError = name.isEmpty ? 'wallet.name_required'.tr() : null;
      if (balanceText.isEmpty) {
        _balanceError = 'wallet.balance_required'.tr();
      } else if (balance == null) {
        _balanceError = 'wallet.invalid_number'.tr();
      } else {
        _balanceError = null;
      }
    });

    if (_nameError != null || _balanceError != null) return;

    // Read currency from global provider — static symbol, not translated
    final currency = ref.read(defaultCurrencyProvider).valueOrNull;
    widget.onAdd(
      WalletEntity(
        id: 0, // Database handles auto-increment
        name: name,
        type: _type,
        balance: balance!,
        currencyCode: currency?.currencyCode ?? 'USD',
        currencySymbol: currency?.currencySymbol ?? '\$',
        currencyNameEn: currency?.currencyNameEn ?? 'US Dollar',
        rateToUsd: currency?.rateToUsd ?? 1.0,
      ),
    );
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
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
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
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'wallet.add_new_wallet'.tr(),
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _nameCtrl,
            onChanged: (val) {
              if (_nameError != null) setState(() => _nameError = null);
            },
            decoration: InputDecoration(
              labelText: 'wallet.wallet_name'.tr(),
              prefixIcon: const Icon(Icons.wallet),
              errorText: _nameError,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Consumer(builder: (context, ref, child) {
            final currency = ref.watch(defaultCurrencyProvider).valueOrNull;
            final symbol = currency?.currencySymbol ?? '\$';
            return TextField(
              controller: _balanceCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (val) {
                if (_balanceError != null) setState(() => _balanceError = null);
              },
              decoration: InputDecoration(
                labelText: 'wallet.initial_balance'.tr(),
                prefixIcon: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(symbol, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                prefixIconConstraints: const BoxConstraints(minWidth: 40, minHeight: 0),
                errorText: _balanceError,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            );
          }),
          const SizedBox(height: 12),
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
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _submit,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'wallet.create_wallet'.tr(),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
