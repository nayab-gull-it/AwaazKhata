import 'package:flutter/material.dart';
import 'package:khata_app/providers/app_state.dart';
import 'package:khata_app/theme/app_theme.dart';
import 'package:provider/provider.dart';

/// Read-only summary of credit activity for the shop.
///
/// "Total sales" here means total credit sales (sum of every udhaar
/// entry ever recorded); "received" is the settled portion and "pending"
/// the outstanding portion. Inventory value is shown as context since
/// there is no cash-sale ledger yet.
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    final received = appState.udhaar
        .where((entry) => entry.isPaid)
        .fold(0.0, (sum, entry) => sum + entry.amount);
    final pending = appState.totalPendingUdhaar;
    final totalSales = received + pending;
    final inventoryValue = appState.inventory.fold<double>(
      0,
      (sum, item) => sum + item.quantity * item.salePrice,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SummaryCard(
            icon: Icons.storefront_outlined,
            label: 'Total Sales (Credit)',
            value: 'Rs. ${_fmt(totalSales)}',
            color: AppTheme.navy,
          ),
          _SummaryCard(
            icon: Icons.payments_outlined,
            label: 'Total Received',
            value: 'Rs. ${_fmt(received)}',
            color: AppTheme.greenAccent,
          ),
          _SummaryCard(
            icon: Icons.account_balance_wallet_outlined,
            label: 'Total Pending',
            value: 'Rs. ${_fmt(pending)}',
            color: AppTheme.error,
          ),
          _SummaryCard(
            icon: Icons.inventory_2_outlined,
            label: 'Inventory Value (Sale)',
            value: 'Rs. ${_fmt(inventoryValue)}',
            color: AppTheme.textSecondary,
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              'Sales are credit (udhaar) sales recorded in this app. '
              'Cash sales are not tracked yet.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }

  String _fmt(double value) => value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(2);
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color.withValues(alpha: 0.12),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
