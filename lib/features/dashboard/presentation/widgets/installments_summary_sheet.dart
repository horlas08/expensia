import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:smooth_sheets/smooth_sheets.dart';
import 'package:animate_do/animate_do.dart';

import '../../../../core/services/database_service.dart';
import '../../../transactions/presentation/pages/transactions_page.dart';

class InstallmentsSummarySheet extends ConsumerStatefulWidget {
  const InstallmentsSummarySheet({super.key, required this.currencySymbol});
  final String currencySymbol;

  @override
  ConsumerState<InstallmentsSummarySheet> createState() => _InstallmentsSummarySheetState();
}

class _InstallmentsSummarySheetState extends ConsumerState<InstallmentsSummarySheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late Future<List<Map<String, dynamic>>> _activeInstallmentsFuture;
  late Future<List<Map<String, dynamic>>> _paidInstallmentsFuture;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  void _loadData() {
    _activeInstallmentsFuture = _fetchInstallments('active');
    _paidInstallmentsFuture = _fetchInstallments('paid');
  }

  Future<List<Map<String, dynamic>>> _fetchInstallments(String status) async {
    final service = DatabaseService();
    final db = await service.database;
    await service.normalizeDebtAndInstallmentStates(database: db);
    return db.rawQuery(
      "SELECT t.*, p.name as person_name FROM installments t LEFT JOIN persons p ON t.person_id = p.id WHERE ${status == 'active' ? "t.status IN ('active', 'partial')" : 't.status = ?'} ORDER BY t.id DESC",
      status == 'active' ? [] : [status],
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
            'dashboard.installment'.tr(),
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
            _InstallmentListView(
              future: _activeInstallmentsFuture,
              symbol: widget.currencySymbol,
              onRefresh: () {
                setState(_loadData);
              },
            ),
            _InstallmentListView(
              future: _paidInstallmentsFuture,
              symbol: widget.currencySymbol,
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

class _InstallmentListView extends StatelessWidget {
  const _InstallmentListView({
    required this.future,
    required this.symbol,
    required this.onRefresh,
  });
  final Future<List<Map<String, dynamic>>> future;
  final String symbol;
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
                Icon(Icons.business_center_outlined, size: 64, color: cs.onSurface.withOpacity(0.2)),
                const SizedBox(height: 16),
                Text(
                  'dashboard.no_installments_found'.tr(),
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
            // Usually 'type' = 'for_you' or 'on_you'
            final isForYou = item['type'] == 'for_you'; 
            final remainingPrice =
                (item['remaining_price'] as num?)?.toDouble() ?? 0.0;
            final remainingPriceText = remainingPrice.toStringAsFixed(2);
            final remainingMonths = item['remaining_months'];
            final personName = item['person_name'] ?? 'common.unknown'.tr();

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
                    final tx = await DatabaseService().getMainTransactionForInstallment(item['id']);
                    if (tx != null && context.mounted) {
                      final style = TransactionListItem.getStyle(context, tx);
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => TransactionDetailPage(
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
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.business_rounded,
                      color: Colors.orange,
                    ),
                  ),
                  title: Text(
                    personName,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  subtitle: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${isForYou ? 'dashboard.for_you'.tr() : 'dashboard.on_you'.tr()} • $remainingMonths mos left',
                          style: TextStyle(color: cs.onSurfaceVariant),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _StatusBadge(status: item['status'] as String? ?? 'active'),
                    ],
                  ),
                  trailing: Text(
                    '$symbol$remainingPriceText',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.orange,
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

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isPartial = status == 'partial';
    final color = isPartial ? Colors.orange : cs.primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        isPartial ? 'dashboard.partial'.tr() : 'dashboard.active'.tr(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}
