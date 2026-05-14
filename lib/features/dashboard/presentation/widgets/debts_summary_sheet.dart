import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:smooth_sheets/smooth_sheets.dart';
import 'package:animate_do/animate_do.dart';
import '../../../../core/utils/currency_formatter.dart';

import '../../../../core/services/database_service.dart';
import '../../../transactions/presentation/pages/transactions_page.dart';

class DebtsSummarySheet extends ConsumerStatefulWidget {
  const DebtsSummarySheet({super.key, required this.currencySymbol});
  final String currencySymbol;

  static Future<void> show(BuildContext context, String currencySymbol) {
    return showModalSheet(
      context: context,
      builder: (context) => DebtsSummarySheet(currencySymbol: currencySymbol),
    );
  }

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
    final service = DatabaseService();
    final db = await service.database;
    await service.normalizeDebtAndInstallmentStates(database: db);
    return db.rawQuery('''
      WITH opening_tx AS (
        SELECT
          debt_id,
          direction,
          ROW_NUMBER() OVER (
            PARTITION BY debt_id
            ORDER BY is_opening DESC, id ASC
          ) AS rn
        FROM transactions
        WHERE type = 'debt' AND debt_id IS NOT NULL
      ),
      debt_ledger AS (
        SELECT
          debt_id,
          COALESCE(SUM(CASE WHEN direction = 'plus' THEN amount ELSE 0 END), 0) AS total_plus,
          COALESCE(SUM(CASE WHEN direction = 'min' THEN amount ELSE 0 END), 0) AS total_min
        FROM transactions
        WHERE type = 'debt' AND debt_id IS NOT NULL
        GROUP BY debt_id
      )
      SELECT
        d.*,
        p.name AS person_name,
        CASE
          WHEN l.total_plus > l.total_min THEN 'plus'
          WHEN l.total_min > l.total_plus THEN 'min'
          ELSE o.direction
        END AS opening_direction,
        ABS(l.total_plus - l.total_min) AS current_amount
      FROM debts d
      LEFT JOIN persons p ON d.person_id = p.id
      LEFT JOIN debt_ledger l ON l.debt_id = d.id
      LEFT JOIN opening_tx o ON o.debt_id = d.id AND o.rn = 1
      WHERE ${status == 'active' ? "d.status IN ('active', 'partial')" : "d.status = ?"}
      ORDER BY d.id DESC
    ''', status == 'active' ? [] : [status]);
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
      snapGrid: const SheetSnapGrid.stepless(minOffset: SheetOffset(0.5)),
      child: SheetContentScaffold(
        backgroundColor: cs.surface,
        topBar: AppBar(
          toolbarHeight: 60,
          backgroundColor: cs.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white),
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
            labelStyle: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
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
              onRefresh: () {
                setState(_loadData);
              },
            ),
            _DebtListView(
              future: _paidDebtsFuture,
              onRefresh: () {
                setState(_loadData);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _DebtListView extends StatelessWidget {
  const _DebtListView({required this.future, required this.onRefresh});
  final Future<List<Map<String, dynamic>>> future;
  final VoidCallback onRefresh;

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
          return Center(child: Text('${'common.error'.tr()}: ${snap.error}'));
        }
        final data = snap.data ?? [];
        if (data.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.account_balance_wallet_outlined,
                  size: 64,
                  color: cs.onSurface.withValues(alpha: 0.2),
                ),
                const SizedBox(height: 16),
                Text(
                  'dashboard.no_debts_found'.tr(),
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 16),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: EdgeInsets.fromLTRB(
            16,
            20,
            16,
            32 + MediaQuery.of(context).padding.bottom,
          ),
          itemCount: data.length,
          itemBuilder: (context, i) {
            final item = data[i];
            final isOnYou =
                (item['opening_direction'] as String? ?? 'plus') == 'plus';
            final amount = (item['current_amount'] as num?)?.toDouble() ?? 0.0;
            final amountText = CurrencyFormatter.format(amount);
            final personName = item['person_name'] ?? 'common.unknown'.tr();
            final amountColor = isOnYou ? Colors.red : Colors.green;

            return FadeInUp(
              delay: Duration(milliseconds: 50 * i),
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: cs.outlineVariant.withValues(alpha: 0.3),
                  ),
                ),
                child: ListTile(
                  onTap: () async {
                    final tx = await DatabaseService()
                        .getMainTransactionForDebt(item['id']);
                    if (tx != null && context.mounted) {
                      final style = TransactionListItem.getStyle(context, tx);
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (context) => TransactionDetailPage(
                                tx: tx,
                                iconData: style.icon,
                                iconColor: style.color,
                              ),
                        ),
                      );
                      if (context.mounted) {
                        onRefresh();
                      }
                    }
                  },
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  leading: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: amountColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(Icons.person_rounded, color: amountColor),
                  ),
                  title: AutoSizeText(
                    personName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    maxLines: 1,
                    minFontSize: 12,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: AutoSizeText(
                    isOnYou ? 'dashboard.on_you'.tr() : 'dashboard.for_you'.tr(),
                    style: TextStyle(
                      color: amountColor.withValues(alpha: 0.8),
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    minFontSize: 10,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        amountText,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: amountColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      _StatusBadge(
                        status: item['status'] as String? ?? 'active',
                      ),
                    ],
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

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isPartial = status == 'partial';
    final color = isPartial ? Colors.orange : cs.primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        isPartial ? 'dashboard.partial'.tr() : 'dashboard.active'.tr(),
        style: TextStyle(
          fontSize: 8,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}
