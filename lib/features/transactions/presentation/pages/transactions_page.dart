import 'package:flutter/material.dart';
import 'package:animations/animations.dart';
import 'package:animate_do/animate_do.dart';

class TransactionsPage extends StatelessWidget {
  const TransactionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transactions', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(24),
        itemCount: 10,
        itemBuilder: (context, index) {
          return FadeInUp(
            delay: Duration(milliseconds: 100 * index),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: OpenContainer(
                transitionType: ContainerTransitionType.fade,
                transitionDuration: const Duration(milliseconds: 500),
                openBuilder: (context, _) => TransactionDetailPage(id: index),
                closedElevation: 0,
                closedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                closedColor: Theme.of(context).colorScheme.surface,
                closedBuilder: (context, openContainer) {
                  return ListTile(
                    onTap: openContainer,
                    leading: CircleAvatar(
                      backgroundColor: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.1),
                      child: Icon(Icons.restaurant, color: Theme.of(context).colorScheme.secondary),
                    ),
                    title: Text('Restaurant $index', style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: const Text('23 Oct, 2026'),
                    trailing: const Text('-\$45.00', style: TextStyle(fontWeight: FontWeight.bold)),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}

class TransactionDetailPage extends StatelessWidget {
  final int id;
  const TransactionDetailPage({super.key, required this.id});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detail'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Center(
              child: CircleAvatar(
                radius: 40,
                backgroundColor: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.1),
                child: Icon(Icons.restaurant, size: 40, color: Theme.of(context).colorScheme.secondary),
              ),
            ),
            const SizedBox(height: 24),
            Text('Restaurant $id', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('23 Oct, 2026 at 19:40', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                children: [
                  _buildRow('Status', 'Completed', Colors.green),
                  const Divider(height: 32),
                  _buildRow('Amount', '-\$45.00', Theme.of(context).colorScheme.onSurface),
                  const Divider(height: 32),
                  _buildRow('Category', 'Food & Dining', Theme.of(context).colorScheme.onSurface),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(String label, String value, Color valueColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey)),
        Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: valueColor, fontSize: 16)),
      ],
    );
  }
}
