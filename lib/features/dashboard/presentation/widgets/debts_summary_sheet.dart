import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:smooth_sheets/smooth_sheets.dart';
import 'package:animate_do/animate_do.dart';

import '../../../../core/services/database_service.dart';
import '../../../transactions/presentation/pages/transactions_page.dart';

class DebtsSummarySheet extends ConsumerStatefulWidget {
  const DebtsSummarySheet({super.key, required this.currencySymbol});
  final String currencySymbol;

  @override
  ConsumerState<DebtsSummarySheet> createState() => _DebtsSummarySheetState();
}

class _DebtsSummarySheetState extends ConsumerState<DebtsSummarySheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late Future<List<Map<String, dynamic>>> _activeDebtsFuture;
  late Future<List<Map<String, dynamic>>> _paidDebtsFuture;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  void _loadData() {
    _activeDebtsFuture = _fetchDebts('active');
    _paidDebtsFuture = _fetchDebts('paid');
  }

  Future<List<Map<String, dynamic>>> _fetchDebts(String status) async {
    final db = await DatabaseService().database;
    return db.rawQuery(
      'SELECT t.*, p.name as person_name FROM debts t LEFT JOIN persons p ON t.person_id = p.id WHERE t.status = ? ORDER BY t.id DESC',
      [status],
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Sheet(
      initialOffset: const SheetOffset(1),
      snapGrid: const SheetSnapGrid.stepless(
        minOffset: SheetOffset(0.5),
      ),
      child: SheetContentScaffold(
        backgroundColor: cs.surface,
        topBar: AppBar(
          backgroundColor: cs.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white,),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Text(
            'dashboard.debt'.tr(),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          centerTitle: true,
          bottom: TabBar(
            controller: _tabController,
            indicatorColor: Colors.white,
            indicatorWeight: 3,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white60,
            labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            tabs: [
              Tab(text: 'dashboard.active'.tr()),
              Tab(text: 'dashboard.paid'.tr()),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            _DebtListView(
              future: _activeDebtsFuture,
              symbol: widget.currencySymbol,
            ),
            _DebtListView(
              future: _paidDebtsFuture,
              symbol: widget.currencySymbol,
            ),
          ],
        ),
      ),
    );
  }
}

class _DebtListView extends StatelessWidget {
  const _DebtListView({required this.future, required this.symbol});
  final Future<List<Map<String, dynamic>>> future;
  final String symbol;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(child: Text('Err: ${snap.error}'));
        }
        final data = snap.data ?? [];
        if (data.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.account_balance_wallet_outlined, size: 64, color: cs.onSurface.withOpacity(0.2)),
                const SizedBox(height: 16),
                Text(
                  'No debts found',
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 16),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          itemCount: data.length,
          itemBuilder: (context, i) {
            final item = data[i];
            final isForYou = (item['income'] as num).toDouble() > 0;
            final amount = isForYou ? item['income'] : item['expense'];
            final personName = item['person_name'] ?? 'Unknown';

            return FadeInUp(
              delay: Duration(milliseconds: 50 * i),
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: cs.outlineVariant.withOpacity(0.3)),
                ),
                child: ListTile(
                  onTap: () async {
                    final tx = await DatabaseService().getMainTransactionForDebt(item['id']);
                    if (tx != null && context.mounted) {
                      final style = TransactionListItem.getStyle(tx);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => TransactionDetailPage(
                            tx: tx,
                            iconData: style.icon,
                            iconColor: style.color,
                          ),
                        ),
                      );
                    }
                  },
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: (isForYou ? Colors.green : Colors.red).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      Icons.person_rounded,
                      color: isForYou ? Colors.green : Colors.red,
                    ),
                  ),
                  title: Text(
                    personName,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  subtitle: Text(
                    isForYou ? 'dashboard.for_you'.tr() : 'dashboard.on_you'.tr(),
                    style: TextStyle(color: cs.onSurfaceVariant),
                  ),
                  trailing: Text(
                    '$symbol$amount',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: isForYou ? Colors.green : Colors.red,
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
