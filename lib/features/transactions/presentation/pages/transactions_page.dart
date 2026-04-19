import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:animations/animations.dart';
import 'package:animate_do/animate_do.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:smooth_sheets/smooth_sheets.dart';

import '../../../../core/constants/category_icons.dart';
import '../../../../core/utils/transaction_grouper.dart';
import '../../../../core/utils/url_launcher_utils.dart';
import '../../../../core/services/database_service.dart';
import '../../../../core/providers/currency_provider.dart';
import '../../../dashboard/presentation/providers/dashboard_provider.dart';
import '../providers/transaction_filter_provider.dart';
import '../widgets/transaction_filter_sheet.dart';
import '../widgets/wallet_picker_sheet.dart';
import '../widgets/add_debt_payment_sheet.dart';
import 'add_income_expense_page.dart';
import 'add_debt_page.dart';
import 'add_installment_page.dart';

/// Provider for filtered transactions based on the current filter state
final filteredTransactionsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final filter = ref.watch(transactionFilterProvider);
  final dbService = DatabaseService();
  
  if (filter.isEmpty) {
    return await dbService.getAllTransactions();
  }
  
  return await dbService.getFilteredTransactions(
    type: filter.type,
    direction: filter.direction,
    categoryId: filter.categoryId,
    walletId: filter.walletId,
    personId: filter.personId,
    fromDate: filter.fromDate,
    toDate: filter.toDate,
  );
});

class TransactionsPage extends ConsumerWidget {
  const TransactionsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactionsAsync = ref.watch(filteredTransactionsProvider);
    final filter = ref.watch(transactionFilterProvider);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text('history.title'.tr(), style: const TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                onPressed: () => TransactionFilterSheet.show(context),
                icon: const Icon(Icons.tune_rounded),
                tooltip: 'history.filter_title'.tr(),
              ),
              if (filter.activeCount > 0)
                Positioned(
                  top: 10,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                    child: Text(
                      filter.activeCount.toString(),
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: transactionsAsync.when(
        data: (transactions) {
          if (transactions.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.receipt_long_outlined, size: 64, color: cs.onSurface.withValues(alpha: 0.1)),
                  const SizedBox(height: 16),
                  Text('history.empty'.tr(), style: TextStyle(color: cs.onSurfaceVariant)),
                ],
              ),
            );
          }

          final grouped = groupTransactionsByDate(transactions, context);
          final entries = grouped.entries.toList();

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            itemCount: entries.length,
            itemBuilder: (context, index) {
              final entry = entries[index];
              
              double income = 0;
              double expense = 0;
              for (var tx in entry.value) {
                if (tx['direction'] == 'plus') {
                  income += (tx['amount'] as num?)?.toDouble() ?? 0.0;
                } else if (tx['direction'] == 'min') {
                  expense += (tx['amount'] as num?)?.toDouble() ?? 0.0;
                }
              }
              
              return FadeInUp(
                delay: Duration(milliseconds: 50 * (index % 10)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0, bottom: 16.0),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: cs.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              entry.key,
                              style: TextStyle(
                                color: cs.primary,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Divider(
                              color: cs.outlineVariant.withValues(alpha: 0.3),
                            ),
                          ),
                          if (income > 0) ...[
                            const SizedBox(width: 8),
                            const Icon(Icons.arrow_downward_rounded, color: Colors.green, size: 12),
                            const SizedBox(width: 2),
                            Text(
                              income.toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), ''),
                              style: const TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ],
                          if (expense > 0) ...[
                            const SizedBox(width: 8),
                            const Icon(Icons.arrow_upward_rounded, color: Colors.red, size: 12),
                            const SizedBox(width: 2),
                            Text(
                              expense.toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), ''),
                              style: const TextStyle(color: Colors.red, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ],
                      ),
                    ),
                    ...entry.value.map((tx) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: TransactionListItem(tx: tx),
                      );
                    }),
                  ],
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('common.error_prefix'.tr(args: ['$err']))),
      ),
    );
  }
}

class TransactionListItem extends ConsumerWidget {
  final Map<String, dynamic> tx;

  const TransactionListItem({super.key, required this.tx});

  static ({IconData icon, Color color}) getStyle(Map<String, dynamic> tx) {
    final type = tx['type'] as String;
    final categoryName = tx['category_name'] as String? ?? 'wallet.other'.tr();

    switch (type) {
      case 'transfer':
        return (icon: Icons.swap_horiz_rounded, color: Colors.blue);
      case 'debt':
        return (icon: Icons.handshake_rounded, color: Colors.orange);
      case 'installment':
        return (icon: Icons.credit_card_rounded, color: Colors.purple);
      default:
        return (
          icon: CategoryIcons.getIcon(categoryName),
          color: CategoryIcons.getColor(categoryName)
        );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final type = tx['type'] as String;
    final amount = (tx['amount'] as num).toDouble();
    final date = DateTime.parse(tx['date'] as String);
    final notes = tx['notes'] as String? ?? '';
    final categoryName = tx['category_name'] as String? ?? 'wallet.other'.tr();
    
    // Custom styling based on type
    final style = getStyle(tx);
    final iconData = style.icon;
    final iconColor = style.color;
    
    String displayTitle;
    String displaySubtitle;

    switch (type) {
      case 'transfer':
        displayTitle = 'transfer.title'.tr();
        displaySubtitle = '${tx['wallet_name']} → ${tx['to_wallet_name']}';
        break;
      case 'debt':
        displayTitle = 'dashboard.debt'.tr();
        displaySubtitle = tx['person_name'] ?? 'history.private'.tr();
        break;
      case 'installment':
        displayTitle = 'history.installment_deposit'.tr();
        displaySubtitle = tx['person_name'] ?? notes;
        break;
      default: // 'transaction'
        displayTitle = categoryName;
        displaySubtitle = notes.isNotEmpty ? notes : (tx['wallet_name'] ?? '');
    }

    final direction = tx['direction'] as String? ?? 'min';
    final isPositive = direction == 'plus';
    final isNeutral = direction == 'neutral'; // transfers

    final amountPrefix = isNeutral ? '' : (isPositive ? '+ ' : '- ');
    final amountColor = isNeutral ? cs.onSurface : (isPositive ? Colors.green : Colors.red);

    return OpenContainer(
      transitionType: ContainerTransitionType.fade,
      transitionDuration: const Duration(milliseconds: 500),
      openBuilder: (context, _) => TransactionDetailPage(tx: tx, iconData: iconData, iconColor: iconColor),
      closedElevation: 0,
      closedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      closedColor: cs.surfaceContainerLow,
      closedBuilder: (context, openContainer) {
        return ListTile(
          onTap: openContainer,
          onLongPress: () async {
            final confirm = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: Text('history.delete_transaction_title'.tr()),
                content: Text('history.delete_transaction_confirm'.tr()),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('common.cancel'.tr())),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: Text('common.delete'.tr(), style: const TextStyle(color: Colors.red)),
                  ),
                ],
              ),
            );
            if (confirm == true) {
              await DatabaseService().deleteAnyTransaction(tx['id'] as int, tx['type'] as String);
              ref.invalidate(filteredTransactionsProvider);
              ref.invalidate(dashboardMetricsProvider);
              ref.invalidate(recentTransactionsProvider);
            }
          },
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(iconData, color: iconColor, size: 24),
          ),
          title: Text(displayTitle, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text(
            displaySubtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$amountPrefix${amount.abs().toStringAsFixed(2)}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: amountColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                DateFormat('MMM dd').format(date),
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 11),
              ),
            ],
          ),
        );
      },
    );
  }
}

class TransactionDetailPage extends ConsumerStatefulWidget {
  final Map<String, dynamic> tx;
  final IconData iconData;
  final Color iconColor;

  const TransactionDetailPage({
    super.key, 
    required this.tx,
    required this.iconData,
    required this.iconColor,
  });

  @override
  ConsumerState<TransactionDetailPage> createState() => _TransactionDetailPageState();
}

class _TransactionDetailPageState extends ConsumerState<TransactionDetailPage> {
  List<Map<String, dynamic>> _debtPayments = [];
  List<Map<String, dynamic>> _installmentDetails = [];
  List<Map<String, dynamic>> _wallets = [];
  Map<String, dynamic> _fullTx = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fullTx = Map<String, dynamic>.from(widget.tx);
    _loadData();
  }

  Future<void> _loadData() async {
    final dbService = DatabaseService();
    final dbRaw = await dbService.database;
    final type = widget.tx['type'] as String;
    final id = widget.tx['id'] as int;

    final wallets = await dbService.getWallets();
    
    List<Map<String, dynamic>> debts = [];
    List<Map<String, dynamic>> installments = [];
    
    if (type == 'debt') {
      final res = await dbRaw.query('debts', where: 'id = ?', whereArgs: [id]);
      if (res.isNotEmpty) _fullTx.addAll(res.first);
      
      final debtId = widget.tx['debt_id'] as int? ?? id;
      debts = await dbService.getDebtTransactions(debtId);
    } else if (type == 'installment') {
      final res = await dbRaw.query('installments', where: 'id = ?', whereArgs: [id]);
      if (res.isNotEmpty) _fullTx.addAll(res.first);
      
      final instId = widget.tx['installment_id'] as int? ?? id;
      installments = await dbService.getInstallmentDetails(instId);
    } else {
      final res = await dbRaw.query('transactions', where: 'id = ?', whereArgs: [id]);
      if (res.isNotEmpty) _fullTx.addAll(res.first);
    }

    if (mounted) {
      setState(() {
        _wallets = wallets;
        _debtPayments = debts;
        _installmentDetails = installments;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final cs = Theme.of(context).colorScheme;
    final date = DateTime.parse((_fullTx['date'] ?? widget.tx['date']) as String);
    final type = (_fullTx['type'] ?? widget.tx['type']) as String;
    final amount = ((_fullTx['amount'] ?? widget.tx['amount']) as num).toDouble();
    final direction = _fullTx['direction'] as String? ?? widget.tx['direction'] as String? ?? 'min';
    final notes = _fullTx['notes'] as String? ?? '';
    final imageUrl = _fullTx['image_url'] as String? ?? _fullTx['image_path'] as String?;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(_titleForType(type)),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_rounded),
            onPressed: () => _handleEdit(context, type),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (type == 'debt') _buildDebtActions(context),
              if (type == 'debt') const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => _confirmDelete(context),
                  icon: const Icon(Icons.delete_rounded),
                  label: Text('history.delete_transaction_title'.tr()),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      body: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  // ── HERO ICON ──
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: widget.iconColor.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(widget.iconData, size: 48, color: widget.iconColor),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // ── AMOUNT ──
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        direction == 'plus' ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                        color: direction == 'plus' ? Colors.green : Colors.red,
                        size: 20,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        amount.toStringAsFixed(2),
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: direction == 'plus' ? Colors.green : Colors.red,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        ref.watch(currencySymbolProvider),
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: cs.onSurfaceVariant,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    DateFormat('MMMM dd, yyyy  •  HH:mm').format(date),
                    style: TextStyle(color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(height: 32),
                  
                  // ── DETAILS SECTION ──
                  _buildDetailSection(context, [
                    _buildRow(context, 'common.type'.tr(), type.toUpperCase()),
                    if (widget.tx['category_name'] != null)
                      _buildRow(context, 'transaction.category'.tr(), widget.tx['category_name']),
                    _buildRow(context, 'transaction.wallet'.tr(), widget.tx['wallet_name'] ?? 'common.na'.tr()),
                    if (widget.tx['to_wallet_name'] != null)
                      _buildRow(context, 'transfer.to_wallet'.tr(), widget.tx['to_wallet_name']),
                    if ((_fullTx['person_name'] ?? widget.tx['person_name']) != null)
                      _buildRow(
                        context, 
                        'common.person'.tr(), 
                        _fullTx['person_name'] ?? widget.tx['person_name'],
                        trailing: ((_fullTx['person_phone'] ?? widget.tx['person_phone']) != null && ((_fullTx['person_phone'] ?? widget.tx['person_phone']) as String).isNotEmpty)
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  onPressed: () => UrlLauncherUtils.launchWhatsApp(context, _fullTx['person_phone'] ?? widget.tx['person_phone']),
                                  icon: const Icon(Icons.message_rounded, size: 20, color: Colors.green),
                                  style: IconButton.styleFrom(
                                    backgroundColor: Colors.green.withValues(alpha: 0.1),
                                    padding: const EdgeInsets.all(8),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  onPressed: () => UrlLauncherUtils.launchCall(context, _fullTx['person_phone'] ?? widget.tx['person_phone']),
                                  icon: const Icon(Icons.phone_rounded, size: 20, color: Colors.blue),
                                  style: IconButton.styleFrom(
                                    backgroundColor: Colors.blue.withValues(alpha: 0.1),
                                    padding: const EdgeInsets.all(8),
                                  ),
                                ),
                              ],
                            )
                          : null,
                      ),
                    _buildRow(
                      context, 
                        'history.detail_type'.tr(), 
                        direction == 'plus' 
                          ? (type == 'debt' ? 'dashboard.for_you'.tr() : 'categories.income'.tr())
                          : (type == 'debt' ? 'dashboard.on_you'.tr() : 'categories.expense'.tr()),
                      valueColor: direction == 'plus' ? Colors.green : Colors.red,
                    ),
                  ]),

                  // ── DEBT PAYMENT HISTORY ──
                  if (type == 'debt') ...[
                    const SizedBox(height: 32),
                    _buildSectionHeader(context, 'history.payment_history'.tr(), Icons.history_rounded),
                    const SizedBox(height: 12),
                    if (_debtPayments.isEmpty)
                      _buildEmptyState('history.no_payment_records'.tr())
                    else
                      ..._debtPayments.map((p) => _buildDebtPaymentCard(context, p)),
                  ],

                  // ── INSTALLMENT SCHEDULE ──
                  if (type == 'installment') ...[
                    const SizedBox(height: 32),
                    _buildSectionHeader(context, 'history.repayment_schedule'.tr(), Icons.calendar_month_rounded),
                    const SizedBox(height: 12),
                    if (_installmentDetails.isEmpty)
                      _buildEmptyState('history.no_schedule_found'.tr())
                    else
                      ..._installmentDetails.asMap().entries.map((e) => 
                        _buildInstallmentDetailCard(context, e.value, e.key + 1)),
                  ],

                  // ── NOTES ──
                  if (notes.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    _buildDetailSection(context, [
                      _buildRow(context, 'common.notes'.tr(), notes, isMultiline: true),
                    ]),
                  ],

                  // ── IMAGE/RECEIPT ──
                  if (imageUrl != null && imageUrl.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionHeader(context, 'common.receipt'.tr(), Icons.receipt_long_rounded),
                        const SizedBox(height: 12),
                        GestureDetector(
                          onTap: () {
                            showDialog(
                              context: context,
                              builder: (context) => Dialog(
                                backgroundColor: Colors.transparent,
                                insetPadding: const EdgeInsets.all(8),
                                child: InteractiveViewer(
                                  clipBehavior: Clip.none,
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(16),
                                    child: Image.file(
                                      File(imageUrl),
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.file(
                              File(imageUrl),
                              width: double.infinity,
                              height: 200,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  void _handleEdit(BuildContext context, String type) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) {
          switch (type) {
            case 'debt':
              return AddDebtPage(initialTransaction: _fullTx);
            case 'installment':
              return AddInstallmentPage(initialTransaction: _fullTx);
            default:
              return AddIncomeExpensePage(
                transactionType: _fullTx['type'] as String? ?? 'expense',
                initialTransaction: _fullTx,
              );
          }
        },
      ),
    );
    if (result == true && mounted) {
      ref.invalidate(filteredTransactionsProvider);
      ref.invalidate(dashboardMetricsProvider);
      ref.invalidate(recentTransactionsProvider);
      Navigator.pop(context); // close detail page after edit
    }
  }

  String _titleForType(String type) {
    switch (type) {
      case 'debt': return 'history.debt_detail'.tr();
      case 'installment': return 'history.installment_detail'.tr();
      case 'transfer': return 'history.transfer_detail'.tr();
      default: return 'history.transaction_detail'.tr();
    }
  }

  // ── DEBT ACTIONS (bottom bar) ──
  Widget _buildDebtActions(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(top: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.2))),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _openDebtPaymentSheet(context, 'min'),
              icon: const Icon(Icons.arrow_upward_rounded, size: 18),
              label: Text('transaction.borrowed'.tr()),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _openDebtPaymentSheet(context, 'plus'),
              icon: const Icon(Icons.arrow_downward_rounded, size: 18),
              label: Text('transaction.lent'.tr()),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.green,
                side: const BorderSide(color: Colors.green),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openDebtPaymentSheet(BuildContext context, String direction) {
    Navigator.push(
      context,
      ModalSheetRoute(
        builder: (ctx) => AddDebtPaymentSheet(
          debtId: widget.tx['id'] as int,
          direction: direction,
          onSaved: () {
            ref.invalidate(filteredTransactionsProvider);
            ref.invalidate(dashboardMetricsProvider);
            ref.invalidate(recentTransactionsProvider);
            _loadData();
          },
        ),
      ),
    );
  }

  // ── INSTALLMENT TOGGLE ──
  void _toggleInstallmentPaid(Map<String, dynamic> detail) async {
    final isPaid = detail['is_paid'] == 1;
    
    if (!isPaid) {
      // Need to pick a wallet to pay from
      final wallet = await showWalletPickerSheet(context, ref, selectedId: null);
      if (wallet == null) return;
      await DatabaseService().toggleInstallmentDetailPaid(detail['id'] as int, wallet.id);
    } else {
      // Confirm unpay
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('history.undo_payment'.tr()),
          content: Text('history.undo_payment_confirm'.tr()),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('common.cancel'.tr())),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('common.confirm'.tr(), style: const TextStyle(color: Colors.red))),
          ],
        ),
      );
      if (confirm != true) return;
      await DatabaseService().toggleInstallmentDetailPaid(detail['id'] as int, 0);
    }
    
    ref.invalidate(filteredTransactionsProvider);
    ref.invalidate(dashboardMetricsProvider);
    _loadData();
  }

  // ── DELETE CONFIRM ──
  void _confirmDelete(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('common.delete'.tr()),
        content: Text('history.delete_item_confirm'.tr()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('common.cancel'.tr())),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('common.delete'.tr(), style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await DatabaseService().deleteAnyTransaction(
        widget.tx['id'] as int, 
        widget.tx['type'] as String,
      );
      ref.invalidate(filteredTransactionsProvider);
      ref.invalidate(dashboardMetricsProvider);
      ref.invalidate(recentTransactionsProvider);
      if (mounted) Navigator.pop(context);
    }
  }

  // ─── UI BUILDERS ───

  Widget _buildSectionHeader(BuildContext context, String title, IconData icon) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 20, color: cs.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildEmptyState(String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Text(message, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
      ),
    );
  }

  Widget _buildDebtPaymentCard(BuildContext context, Map<String, dynamic> payment) {
    final cs = Theme.of(context).colorScheme;
    final paymentDate = DateTime.tryParse(payment['date'] as String? ?? '');
    final paymentAmount = (payment['amount'] as num?)?.toDouble() ?? 0;
    final dir = payment['direction'] as String? ?? 'min';
    final isIncome = dir == 'plus';
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isIncome 
            ? Colors.green.withValues(alpha: 0.2) 
            : Colors.red.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: (isIncome ? Colors.green : Colors.red).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              isIncome ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
              color: isIncome ? Colors.green : Colors.red,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isIncome ? 'transaction.lent'.tr() : 'transaction.borrowed'.tr(),
                  style: TextStyle(fontWeight: FontWeight.bold, color: cs.onSurface),
                ),
                if (paymentDate != null)
                  Text(
                    DateFormat('MMM dd, yyyy').format(paymentDate),
                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                  ),
              ],
            ),
          ),
          Text(
            paymentAmount.toStringAsFixed(2),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: isIncome ? Colors.green : Colors.red,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstallmentDetailCard(BuildContext context, Map<String, dynamic> detail, int index) {
    final cs = Theme.of(context).colorScheme;
    final dDate = DateTime.tryParse(detail['due_date'] as String? ?? '');
    final isPaid = detail['is_paid'] == 1;
    final detailAmount = (detail['amount'] as num?)?.toDouble() ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: isPaid ? Border.all(color: Colors.green.withValues(alpha: 0.3)) : null,
      ),
      child: Row(
        children: [
          // Index badge
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$index',
              style: TextStyle(fontWeight: FontWeight.bold, color: cs.primary, fontSize: 12),
            ),
          ),
          const SizedBox(width: 12),
          
          // Checkbox
          GestureDetector(
            onTap: () => _toggleInstallmentPaid(detail),
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: isPaid ? Colors.green : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isPaid ? Colors.green : cs.outline,
                  width: 2,
                ),
              ),
              child: isPaid ? const Icon(Icons.check, color: Colors.white, size: 18) : null,
            ),
          ),
          const SizedBox(width: 12),
          
          // Date
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dDate != null ? DateFormat('MMM dd, yyyy').format(dDate) : 'common.na'.tr(),
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: cs.onSurface,
                    decoration: isPaid ? TextDecoration.lineThrough : null,
                  ),
                ),
                Text(
                  isPaid ? 'dashboard.paid'.tr() : 'common.pending'.tr(),
                  style: TextStyle(
                    fontSize: 11,
                    color: isPaid ? Colors.green : Colors.orange,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          
          // Amount
          Text(
            detailAmount.toStringAsFixed(2),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isPaid ? Colors.green : cs.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailSection(BuildContext context, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildRow(BuildContext context, String label, String value, {bool isMultiline = false, Color? valueColor, Widget? trailing}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: isMultiline ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          Text(label, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  value,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: valueColor,
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(height: 4),
                  trailing,
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
