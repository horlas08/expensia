import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:animate_do/animate_do.dart';
import 'package:sqflite/sqflite.dart';

import '../../../../core/models/person_model.dart';
import '../../../../core/providers/currency_provider.dart';
import '../../../../core/services/database_service.dart';
import '../../../../features/wallet/presentation/providers/wallet_provider.dart';
import '../../../../features/wallet/presentation/utils/wallet_localization.dart';
import '../../../../features/dashboard/presentation/providers/dashboard_provider.dart';
import '../widgets/calculator_dialog.dart';
import '../widgets/image_source_sheet.dart';
import '../widgets/two_options_selector.dart';
import '../widgets/wallet_picker_sheet.dart';
import '../../../../features/profile/presentation/pages/persons_page.dart';
import 'package:image_picker/image_picker.dart';

// ---------------------------------------------------------------------------
// Add Installment Page
// ---------------------------------------------------------------------------
class AddInstallmentPage extends ConsumerStatefulWidget {
  const AddInstallmentPage({super.key, this.initialTransaction});
  final Map<String, dynamic>? initialTransaction;

  @override
  ConsumerState<AddInstallmentPage> createState() => _AddInstallmentPageState();
}

class _AddInstallmentPageState extends ConsumerState<AddInstallmentPage> {
  final _totalPriceCtrl = TextEditingController();
  final _depositCtrl = TextEditingController();
  final _lastPaidCtrl = TextEditingController();
  final _monthsCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  final _personCtrl = TextEditingController();

  int? _selectedWalletId;
  bool _saving = false;
  bool _isForYou = false;
  String? _imageUrl;

  @override
  void initState() {
    super.initState();
    if (widget.initialTransaction != null) {
      final tx = widget.initialTransaction!;
      
      final deposit = (tx['deposit'] as num?)?.toDouble() ?? 0.0;
      final remaining = (tx['remaining_price'] as num?)?.toDouble() ?? 0.0;
      final total = deposit + remaining;
      final months = tx['total_months'] as int? ?? 1;
      final lastPaid = (tx['last_payment'] as num?)?.toDouble() ?? 0.0;

      _totalPriceCtrl.text = total > 0 ? total.toStringAsFixed(2) : '';
      _depositCtrl.text = deposit > 0 ? deposit.toStringAsFixed(2) : '';
      _lastPaidCtrl.text = lastPaid > 0 ? lastPaid.toStringAsFixed(2) : '';
      _monthsCtrl.text = months.toString();

      _noteCtrl.text = tx['notes']?.toString() ?? '';
      _personCtrl.text = tx['person_name']?.toString() ?? '';
      _selectedWalletId = tx['wallet_id'] as int?;
      _imageUrl = tx['image_url'] as String?;
      _isForYou = (tx['direction'] as String? ?? 'min') == 'plus';
    }
  }

  @override
  void dispose() {
    _totalPriceCtrl.dispose();
    _depositCtrl.dispose();
    _lastPaidCtrl.dispose();
    _monthsCtrl.dispose();
    _noteCtrl.dispose();
    _personCtrl.dispose();
    super.dispose();
  }

  Color get _themeColor => const Color(0xFFAA00FF); // Purple for Installment

  Future<void> _submit() async {
    final tPrice = double.tryParse(_totalPriceCtrl.text.trim());
    final deposit = double.tryParse(_depositCtrl.text.trim()) ?? 0.0;
    final lastPaid = double.tryParse(_lastPaidCtrl.text.trim()) ?? 0.0;
    final months = int.tryParse(_monthsCtrl.text.trim());

    if (tPrice == null || tPrice <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('transaction.invalid_total_price'.tr())),
      );
      return;
    }
    if (months == null || months <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('transaction.invalid_total_months'.tr())),
      );
      return;
    }
    if (lastPaid < 0 || deposit + lastPaid > tPrice) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('transaction.invalid_last_paid_amount'.tr())),
      );
      return;
    }
    if (lastPaid > 0 && months < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('transaction.invalid_last_paid_months'.tr())),
      );
      return;
    }
    if (_selectedWalletId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('transaction.select_wallet'.tr())),
      );
      return;
    }
    if (_personCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('transaction.enter_person_name'.tr())),
      );
      return;
    }

    final remaining = tPrice - deposit;

    setState(() => _saving = true);

    try {
      final db = DatabaseService();
      final dbRaw = await db.database;

      // Ensure entity exists or create them
      int personId = await _getOrCreatePerson(dbRaw, _personCtrl.text.trim());

      if (widget.initialTransaction != null) {
        final instId = widget.initialTransaction!['id'] as int;
        final oldDeposit = (widget.initialTransaction!['deposit'] as num?)?.toDouble() ?? 
                           (widget.initialTransaction!['amount'] as num).toDouble();
        final oldWalletId = widget.initialTransaction!['wallet_id'] as int;

        // 1. Revert old balance
        if (_isForYou) {
          await ref.read(walletProvider.notifier).withdrawBalance(oldWalletId, oldDeposit);
        } else {
          await ref.read(walletProvider.notifier).addBalance(oldWalletId, oldDeposit);
        }

        // 2. Update installment record
        await dbRaw.update('installments', {
          'person_id': personId,
          'wallet_id': _selectedWalletId,
          'category_id': _installmentCategoryId,
          'deposit': deposit,
          'last_payment': lastPaid,
          'remaining_price': remaining,
          'total_months': months,
          'type': _isForYou ? 'for_you' : 'on_you',
          'image_path': _imageUrl,
          'notes': _noteCtrl.text.trim(),
        }, where: 'id = ?', whereArgs: [instId]);

        final paidDetailsCount = Sqflite.firstIntValue(
              await dbRaw.rawQuery(
                'SELECT COUNT(*) FROM installment_details WHERE installment_id = ? AND is_paid = 1',
                [instId],
              ),
            ) ??
            0;
        if (paidDetailsCount == 0) {
          await dbRaw.delete(
            'installment_details',
            where: 'installment_id = ?',
            whereArgs: [instId],
          );
          final plan = _calculatePlan();
          for (final item in plan) {
            await dbRaw.insert('installment_details', {
              'installment_id': instId,
              'due_date': item['due_date'],
              'amount': item['amount'],
              'is_paid': 0,
              'is_initial': 0,
            });
          }
          if (deposit > 0) {
            await dbRaw.insert('installment_details', {
              'installment_id': instId,
              'due_date': DateTime.now().toIso8601String(),
              'amount': deposit,
              'is_paid': 1,
              'paid_at': DateTime.now().toIso8601String(),
              'wallet_id': _selectedWalletId,
              'is_initial': 1,
            });
          }
        }

        // 3. Update or backfill the main installment transaction.
        final mainTx = await db.getMainTransactionForInstallment(instId);
        final curr = ref.read(defaultCurrencyProvider).valueOrNull;
        final mainTxData = {
          'wallet_id': _selectedWalletId,
          'category_id': _installmentCategoryId,
          'currency_id': curr?.id ?? 1,
          'type': 'installment',
          'direction': _isForYou ? 'plus' : 'min',
          'amount': deposit,
          'notes': 'transaction.deposit_for'.tr(args: [_noteCtrl.text.trim()]),
          'image_url': _imageUrl,
        };
        if (mainTx != null) {
          final txId = mainTx['id'] as int;
          await db.updateTransaction(txId, mainTxData);
        } else {
          await dbRaw.insert('transactions', {
            ...mainTxData,
            'date': DateTime.now().toIso8601String(),
            'is_paid': 1,
            'is_repeat': 0,
            'is_opening': 1,
            'installment_id': instId,
            'person_id': personId,
            'person_name': _personCtrl.text.trim(),
          });
        }

        // 4. Apply new balance
        if (_isForYou) {
          await ref.read(walletProvider.notifier).addBalance(_selectedWalletId!, deposit);
        } else {
          await ref.read(walletProvider.notifier).withdrawBalance(_selectedWalletId!, deposit);
        }
      } else {
        // --- NEW INSTALLMENT ---
        final installmentId = await dbRaw.insert('installments', {
          'person_id': personId,
          'wallet_id': _selectedWalletId,
          'category_id': _installmentCategoryId,
          'deposit': deposit,
          'last_payment': lastPaid,
          'remaining_price': remaining,
          'total_months': months,
          'remaining_months': months,
          'status': 'active',
          'type': _isForYou ? 'for_you' : 'on_you',
          'image_path': _imageUrl,
          'notes': _noteCtrl.text.trim(),
          'created_at': DateTime.now().toIso8601String(),
        });

        // Generation of monthly schedules
        final plan = _calculatePlan();
        for (final item in plan) {
          await dbRaw.insert('installment_details', {
            'installment_id': installmentId,
            'due_date': item['due_date'],
            'amount': item['amount'],
            'is_paid': 0,
            'is_initial': 0,
          });
        }

        if (deposit > 0) {
          await dbRaw.insert('installment_details', {
            'installment_id': installmentId,
            'due_date': DateTime.now().toIso8601String(),
            'amount': deposit,
            'is_paid': 1,
            'paid_at': DateTime.now().toIso8601String(),
            'wallet_id': _selectedWalletId,
            'is_initial': 1,
          });
        }

        // Always create a main installment transaction so the record appears
        // in transaction history, even when the initial deposit is zero.
        final curr = ref.read(defaultCurrencyProvider).valueOrNull;
        await dbRaw.insert('transactions', {
          'wallet_id': _selectedWalletId,
          'category_id': _installmentCategoryId,
          'currency_id': curr?.id ?? 1,
          'type': 'installment',
          'direction': _isForYou ? 'plus' : 'min',
          'amount': deposit,
          'date': DateTime.now().toIso8601String(),
          'is_paid': 1,
          'is_repeat': 0,
          'is_opening': 1,
          'notes': 'transaction.deposit_for'.tr(args: [_noteCtrl.text.trim()]),
          'installment_id': installmentId,
          'person_id': personId,
          'person_name': _personCtrl.text.trim(),
          'image_url': _imageUrl,
        });

        if (deposit > 0) {
          if (_isForYou) {
            await ref.read(walletProvider.notifier).addBalance(_selectedWalletId!, deposit);
          } else {
            await ref.read(walletProvider.notifier).withdrawBalance(_selectedWalletId!, deposit);
          }
        }
      }

      if (!mounted) return;
      ref.invalidate(dashboardMetricsProvider);
      ref.invalidate(recentTransactionsProvider);
      ref.invalidate(allTransactionsProvider);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('transaction.saved'.tr()),
          backgroundColor: const Color(0xFF00C48C),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<int> _getOrCreatePerson(dbRaw, String name) async {
    final list = await dbRaw.query('persons', where: 'name = ?', whereArgs: [name]);
    if (list.isNotEmpty) return list.first['id'] as int;
    return await dbRaw.insert('persons', {'name': name});
  }

  List<Map<String, dynamic>> _calculatePlan() {
    final tPrice = double.tryParse(_totalPriceCtrl.text) ?? 0.0;
    final deposit = double.tryParse(_depositCtrl.text) ?? 0.0;
    final lastPaid = double.tryParse(_lastPaidCtrl.text) ?? 0.0;
    final months = int.tryParse(_monthsCtrl.text) ?? 1;

    if (months < 1) return [];
    if (lastPaid > 0 && months < 2) return [];

    final remaining = tPrice - deposit - lastPaid;
    final normalMonths = lastPaid > 0 ? months - 1 : months;
    final monthly = normalMonths > 0 ? remaining / normalMonths : 0.0;
    final now = DateTime.now();

    return List.generate(months, (i) {
      final dueDate = DateTime(now.year, now.month + i + 1, now.day);
      final isLastMonth = i == months - 1;
      return {
        'month': i + 1,
        'due_date': dueDate.toIso8601String(),
        'amount': isLastMonth && lastPaid > 0 ? lastPaid : monthly,
      };
    });
  }

  int get _installmentCategoryId => _isForYou ? 1001 : 1002;

  void _showPlanPreview() {
    if (_totalPriceCtrl.text.isEmpty || _monthsCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('transaction.enter_amount_and_months'.tr())),
      );
      return;
    }

    final plan = _calculatePlan();
    final cs = Theme.of(context).colorScheme;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.outlineVariant.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'transaction.installment_plan'.tr(),
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'transaction.installment_plan_preview'.tr(),
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: ListView.separated(
                itemCount: plan.length,
                separatorBuilder: (context, index) => Divider(color: cs.outlineVariant.withValues(alpha: 0.1)),
                itemBuilder: (context, index) {
                  final item = plan[index];
                  final date = DateTime.parse(item['due_date']);
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: cs.primary.withValues(alpha: 0.1),
                      child: Text(
                        '#${item['month']}',
                        style: TextStyle(color: cs.primary, fontWeight: FontWeight.bold),
                      ),
                    ),
                    title: Text(
                      'transaction.payment_number'.tr(args: ['${item['month']}']),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(DateFormat('MMMM dd, yyyy').format(date)),
                    trailing: Text(
                      NumberFormat.currency(symbol: '\$').format(item['amount']),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: FilledButton(
                onPressed: () => Navigator.pop(context),
                style: FilledButton.styleFrom(
                  backgroundColor: cs.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: Text('common.close_preview'.tr(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickContact() async {
    final person = await Navigator.push<Person>(
      context,
      MaterialPageRoute(builder: (_) => const PersonsPage(isPicker: true)),
    );
    if (person != null) {
      setState(() {
        _personCtrl.text = person.name;
      });
    }
  }

  Future<void> _openCalculator(TextEditingController ctrl) async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => CalculatorDialog(initialValue: ctrl.text),
    );
    if (result != null) {
      setState(() => ctrl.text = result);
    }
  }

  Future<void> _pickImage() async {
    final ImageSource? source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => const ImageSourceSheet(),
    );
    if (source == null) return;

    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: source);
      if (picked != null) setState(() => _imageUrl = picked.path);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${'transaction.error_picking_image'.tr()}$e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final sym = ref.watch(currencySymbolProvider);
    final wallets = ref.watch(walletProvider);

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: _themeColor,
        foregroundColor: Colors.white,
        title: Text(
          widget.initialTransaction != null ? 'transaction.edit_installment'.tr() : 'dashboard.installment'.tr(),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        children: [
          // ── Hero ──────────────────────────────────────────────────
          FadeInDown(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [_themeColor, _themeColor.withValues(alpha: 0.7)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                children: [
                  TwoOptionsSelector(
                    isLeftSelected: !_isForYou,
                    leftLabel: 'dashboard.on_you'.tr(),
                    rightLabel: 'dashboard.for_you'.tr(),
                    onChanged: (isLeft) {
                      setState(() => _isForYou = !isLeft);
                    },
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'transaction.total_price'.tr(),
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        sym,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: IntrinsicWidth(
                          child: TextField(
                            controller: _totalPriceCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 48,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                            decoration: InputDecoration(
                              hintText: '0.00',
                              hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                              border: InputBorder.none,
                            ),
                            cursorColor: Colors.white,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => _openCalculator(_totalPriceCtrl),
                        icon: const Icon(Icons.calculate_rounded, color: Colors.white70),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // ── Form fields ──────────────────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  FadeInUp(
                    delay: const Duration(milliseconds: 20),
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
                              color: const Color(0xFFFF9800).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.business_rounded,
                              color: Color(0xFFFF9800),
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _personCtrl,
                              decoration: InputDecoration(
                                hintText: 'transaction.entity_hint'.tr(),
                                border: InputBorder.none,
                                isDense: true,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: _pickContact,
                            icon: Icon(Icons.person_add_rounded, color: cs.primary),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  FadeInUp(
                    delay: const Duration(milliseconds: 40),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _depositCtrl,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: InputDecoration(
                                labelText: 'transaction.deposit_initial_paid'.tr(),
                                border: InputBorder.none,
                                isDense: true,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => _openCalculator(_depositCtrl),
                            icon: Icon(Icons.calculate_rounded, color: cs.primary.withValues(alpha: 0.5), size: 20),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  FadeInUp(
                    delay: const Duration(milliseconds: 60),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _lastPaidCtrl,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: InputDecoration(
                                labelText: 'transaction.last_paid'.tr(),
                                border: InputBorder.none,
                                isDense: true,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => _openCalculator(_lastPaidCtrl),
                            icon: Icon(Icons.calculate_rounded, color: cs.primary.withValues(alpha: 0.5), size: 20),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  FadeInUp(
                    delay: const Duration(milliseconds: 80),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _monthsCtrl,
                              keyboardType: const TextInputType.numberWithOptions(decimal: false),
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                              decoration: InputDecoration(
                                labelText: 'transaction.months'.tr(),
                                border: InputBorder.none,
                                isDense: true,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => _openCalculator(_monthsCtrl),
                            icon: Icon(Icons.calculate_rounded, color: cs.primary.withValues(alpha: 0.5), size: 18),
                          ),
                          Container(
                            height: 24,
                            width: 1,
                            color: cs.outlineVariant.withValues(alpha: 0.3),
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                          ),
                          IconButton(
                            onPressed: _showPlanPreview,
                            icon: Icon(Icons.calendar_month_rounded, color: cs.primary, size: 18),
                            tooltip: 'transaction.preview_plan'.tr(),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Wallet
                  FadeInUp(
                    delay: const Duration(milliseconds: 100),
                    child: GestureDetector(
                      onTap: () async {
                        final wallet = await showWalletPickerSheet(context, ref, selectedId: _selectedWalletId);
                        if (wallet != null) {
                          setState(() => _selectedWalletId = wallet.id);
                        }
                      },
                      child: _FormCard(
                        icon: Icons.account_balance_wallet_rounded,
                        color: cs.primary,
                        label: 'transaction.wallet'.tr(),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                _selectedWalletId == null
                                    ? 'transaction.select_wallet'.tr()
                                    : wallets.firstWhere((w) => w.id == _selectedWalletId).displayName(context),
                                style: TextStyle(
                                  color: _selectedWalletId == null ? cs.onSurface.withValues(alpha: 0.5) : cs.onSurface,
                                  fontWeight: _selectedWalletId == null ? FontWeight.normal : FontWeight.bold,
                                ),
                              ),
                            ),
                            Icon(Icons.keyboard_arrow_down_rounded, color: cs.onSurface.withValues(alpha: 0.3)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Note
                  FadeInUp(
                    delay: const Duration(milliseconds: 120),
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
                              color: const Color(0xFFFFBE0B).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.notes_rounded,
                              color: Color(0xFFFFBE0B),
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _noteCtrl,
                              decoration: InputDecoration(
                                hintText: 'transaction.note_hint'.tr(),
                                border: InputBorder.none,
                                isDense: true,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Image Picker
                  FadeInUp(
                    delay: const Duration(milliseconds: 140),
                    child: GestureDetector(
                      onTap: _pickImage,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: _imageUrl == null ? cs.surfaceContainerLow : cs.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: (_imageUrl == null ? cs.onSurface : cs.primary).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.image_rounded,
                                color: _imageUrl == null ? cs.onSurface.withValues(alpha: 0.5) : cs.primary,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _imageUrl == null ? 'transaction.attach_receipt'.tr() : 'transaction.image_attached'.tr(),
                                style: TextStyle(
                                  color: _imageUrl == null ? cs.onSurface.withValues(alpha: 0.5) : cs.primary,
                                  fontWeight: _imageUrl == null ? FontWeight.normal : FontWeight.bold,
                                ),
                              ),
                            ),
                            if (_imageUrl != null)
                              GestureDetector(
                                onTap: () => setState(() => _imageUrl = null),
                                child: Icon(Icons.close_rounded, color: cs.primary, size: 20),
                              )
                            else
                              Icon(Icons.add_a_photo_rounded, color: cs.onSurface.withValues(alpha: 0.3), size: 20),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Save button
                  FadeInUp(
                    delay: const Duration(milliseconds: 160),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _saving ? null : _submit,
                        style: FilledButton.styleFrom(
                          backgroundColor: _themeColor,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                        ),
                        icon: _saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.check_rounded, color: Colors.white),
                        label: Text(
                          'common.save'.tr(),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Reusable form card row
// ---------------------------------------------------------------------------
class _FormCard extends StatelessWidget {
  const _FormCard({
    required this.icon,
    required this.color,
    required this.label,
    required this.child,
  });

  final IconData icon;
  final Color color;
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface.withValues(alpha: 0.5),
                  ),
                ),
                const SizedBox(height: 4),
                child,
              ],
            ),
          ),
        ],
      ),
    );
  }
}
