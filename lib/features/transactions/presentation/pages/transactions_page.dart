import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:animations/animations.dart';
import 'package:animate_do/animate_do.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/category_icons.dart';
import '../../../../core/services/database_service.dart';
import '../../../dashboard/presentation/providers/dashboard_provider.dart';

class TransactionsPage extends ConsumerWidget {
  const TransactionsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactionsAsync = ref.watch(allTransactionsProvider);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text('history.title'.tr(), style: const TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [],
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

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            itemCount: transactions.length,
            itemBuilder: (context, index) {
              final tx = transactions[index];
              return FadeInUp(
                delay: Duration(milliseconds: 50 * (index % 10)),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: _TransactionListItem(tx: tx),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }
}

class _TransactionListItem extends StatelessWidget {
  final Map<String, dynamic> tx;

  const _TransactionListItem({required this.tx});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final type = tx['type'] as String;
    final amount = (tx['amount'] as num).toDouble();
    final date = DateTime.parse(tx['date'] as String);
    final notes = tx['notes'] as String? ?? '';
    final categoryName = tx['category_name'] as String? ?? 'Other';
    
    // Custom styling based on type
    IconData iconData;
    Color iconColor;
    String displayTitle;
    String displaySubtitle;

    switch (type) {
      case 'transfer':
        iconData = Icons.swap_horiz_rounded;
        iconColor = Colors.blue;
        displayTitle = 'Transfer';
        displaySubtitle = '${tx['wallet_name']} → ${tx['to_wallet_name']}';
        break;
      case 'debt':
        iconData = Icons.handshake_rounded;
        iconColor = Colors.orange;
        displayTitle = 'Debt';
        displaySubtitle = tx['person_name'] ?? 'Private';
        break;
      case 'installment':
        iconData = Icons.credit_card_rounded;
        iconColor = Colors.purple;
        displayTitle = 'Installment Deposit';
        displaySubtitle = tx['person_name'] ?? notes;
        break;
      default: // 'transaction'
        iconData = CategoryIcons.getIcon(categoryName);
        iconColor = CategoryIcons.getColor(categoryName);
        displayTitle = categoryName;
        displaySubtitle = notes.isNotEmpty ? notes : (tx['wallet_name'] ?? '');
    }

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
                NumberFormat.currency(symbol: '\$').format(amount),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: type == 'transaction' && amount < 0 ? Colors.red : cs.onSurface,
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

class TransactionDetailPage extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final date = DateTime.parse(tx['date'] as String);
    final type = tx['type'] as String;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transaction Detail'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Center(
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(iconData, size: 48, color: iconColor),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              NumberFormat.currency(symbol: '\$').format(tx['amount']),
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              DateFormat('MMMM dd, yyyy  •  HH:mm').format(date),
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 32),
            
            _buildDetailSection(context, [
              _buildRow(context, 'Type', type.toUpperCase()),
              if (tx['category_name'] != null)
                _buildRow(context, 'Category', tx['category_name']),
              _buildRow(context, 'Wallet', tx['wallet_name'] ?? 'N/A'),
              if (tx['to_wallet_name'] != null)
                _buildRow(context, 'To Wallet', tx['to_wallet_name']),
              if (tx['person_name'] != null)
                _buildRow(context, 'Related Person', tx['person_name']),
            ]),
            
            if (type == 'installment') ...[
              const SizedBox(height: 32),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Repayment Schedule',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 16),
              FutureBuilder<List<Map<String, dynamic>>>(
                future: DatabaseService().getInstallmentDetails(tx['id']),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final details = snapshot.data ?? [];
                  if (details.isEmpty) return const Text('No schedule found');
                  
                  return Column(
                    children: details.map((d) {
                      final dDate = DateTime.parse(d['due_date']);
                      final isPaid = d['is_paid'] == 1;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(12),
                          border: isPaid ? Border.all(color: Colors.green.withValues(alpha: 0.3)) : null,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isPaid ? Icons.check_circle_rounded : Icons.pending_actions_rounded,
                              color: isPaid ? Colors.green : Colors.orange,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(child: Text(DateFormat('MMM dd, yyyy').format(dDate))),
                            Text(
                              NumberFormat.currency(symbol: '\$').format(d['amount']),
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
            ],

            if ((tx['notes'] as String? ?? '').isNotEmpty) ...[
              const SizedBox(height: 24),
              _buildDetailSection(context, [
                _buildRow(context, 'Notes', tx['notes'], isMultiline: true),
              ]),
            ],
          ],
        ),
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

  Widget _buildRow(BuildContext context, String label, String value, {bool isMultiline = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: isMultiline ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          Text(label, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
