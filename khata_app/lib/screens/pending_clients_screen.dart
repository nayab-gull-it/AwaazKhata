import 'package:flutter/material.dart';
import 'package:khata_app/providers/app_state.dart';
import 'package:khata_app/screens/customer_ledger_screen.dart';
import 'package:khata_app/theme/app_theme.dart';
import 'package:provider/provider.dart';

/// Customers with outstanding (unpaid) udhaar, grouped by name.
///
/// Sums every unsettled entry per customer and shows the total owed.
/// Tapping a customer opens their full ledger.
class PendingClientsScreen extends StatelessWidget {
  const PendingClientsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    // Aggregate outstanding amounts per customer (case-insensitive name).
    final totals = <String, ({String name, double amount, int entries})>{};
    for (final entry in appState.udhaar) {
      if (entry.isPaid) continue;
      final key = entry.customerName.trim().toLowerCase();
      if (key.isEmpty) continue;
      final current = totals[key];
      totals[key] = (
        name: entry.customerName,
        amount: (current?.amount ?? 0) + entry.amount,
        entries: (current?.entries ?? 0) + 1,
      );
    }

    final clients = totals.values.toList()
      ..sort((a, b) => b.amount.compareTo(a.amount));

    return Scaffold(
      appBar: AppBar(title: const Text('Pending Clients')),
      body: clients.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.verified_outlined,
                    size: 64,
                    color: Theme.of(context).hintColor,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No pending udhaar.\nAll customers are settled.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: clients.length,
              itemBuilder: (context, index) {
                final client = clients[index];
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor:
                          AppTheme.error.withValues(alpha: 0.12),
                      child: Text(
                        client.name.isEmpty
                            ? '?'
                            : client.name[0].toUpperCase(),
                        style: TextStyle(
                          color: AppTheme.error,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(
                      client.name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    subtitle: Text(
                      '${client.entries} open '
                      '${client.entries == 1 ? 'record' : 'records'}',
                    ),
                    trailing: Text(
                      'Rs. ${_fmt(client.amount)}',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.error,
                          ),
                    ),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => CustomerLedgerScreen(
                            customerName: client.name,
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
    );
  }

  String _fmt(double value) => value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(2);
}
