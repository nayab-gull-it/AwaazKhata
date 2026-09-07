import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:khata_app/models/udhaar_entry.dart';
import 'package:khata_app/providers/app_state.dart';
import 'package:khata_app/services/whatsapp_share_service.dart';
import 'package:khata_app/theme/app_theme.dart';
import 'package:provider/provider.dart';

/// Full transaction history for a single customer.
///
/// Lists every udhaar entry (settled included) whose customer name closely
/// matches the tapped customer, newest first, with running totals for
/// outstanding, settled, and lifetime amounts.
class CustomerLedgerScreen extends StatelessWidget {
  const CustomerLedgerScreen({
    required this.customerName,
    this.phoneNumber,
    super.key,
  });

  /// The name spoken/typed for this customer; entries are fuzzy-matched.
  final String customerName;

  final String? phoneNumber;

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final entries = appState.findUdhaarHistory(customerName);

    final outstanding = entries
        .where((entry) => !entry.isPaid)
        .fold(0.0, (sum, entry) => sum + entry.amount);
    final settled = entries
        .where((entry) => entry.isPaid)
        .fold(0.0, (sum, entry) => sum + entry.amount);

    return Scaffold(
      appBar: AppBar(
        title: Text(customerName),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: 'Share bill on WhatsApp',
            onPressed: () {
              WhatsAppShareService.shareUdhaarBill(
                context,
                phoneNumber: phoneNumber ?? '',
                customerName: customerName,
                amount: outstanding,
                isPaid: outstanding <= 0,
                dateText:
                    'Ledger summary as of ${DateFormat('d MMM yyyy').format(DateTime.now())}',
              );
            },
          ),
        ],
      ),
      body: entries.isEmpty
          ? Center(
              child: Text('No records found for "$customerName"'),
            )
          : Column(
              children: [
                _LedgerHeader(
                  outstanding: outstanding,
                  settled: settled,
                  entryCount: entries.length,
                  phone: phoneNumber ?? '',
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: entries.length,
                    itemBuilder: (context, index) {
                      return _LedgerEntryTile(entry: entries[index]);
                    },
                  ),
                ),
              ],
            ),
    );
  }
}

/// Summary strip at the top of the ledger.
class _LedgerHeader extends StatelessWidget {
  const _LedgerHeader({
    required this.outstanding,
    required this.settled,
    required this.entryCount,
    required this.phone,
  });

  final double outstanding;
  final double settled;
  final int entryCount;
  final String phone;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.navy,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.account_balance_wallet_outlined,
                color: AppTheme.white,
              ),
              const SizedBox(width: 8),
              Text(
                'Outstanding Rs. ${outstanding.toStringAsFixed(0)}',
                style: const TextStyle(
                  color: AppTheme.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          if (phone.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              phone,
              style: TextStyle(
                color: AppTheme.white.withValues(alpha: 0.8),
                fontSize: 13,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            '$entryCount ${entryCount == 1 ? 'record' : 'records'} · '
            'Rs. ${settled.toStringAsFixed(0)} settled so far',
            style: TextStyle(
              color: AppTheme.white.withValues(alpha: 0.85),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

/// One transaction row in the ledger.
class _LedgerEntryTile extends StatelessWidget {
  const _LedgerEntryTile({required this.entry});

  final UdhaarEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('d MMM yyyy, h:mm a');
    final dateText = entry.isPaid && entry.paidAt != null
        ? 'Settled on ${dateFormat.format(entry.paidAt!)}'
        : 'Recorded on ${dateFormat.format(entry.createdAt)}';

    return Card(
      child: ListTile(
        leading: Icon(
          entry.isPaid ? Icons.check_circle_outline : Icons.schedule_outlined,
          color: entry.isPaid ? AppTheme.greenAccent : AppTheme.error,
        ),
        title: Text(
          'Rs. ${entry.amount.toStringAsFixed(0)}',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (entry.description != null &&
                entry.description!.trim().isNotEmpty)
              Text(
                entry.description!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            Text(
              dateText,
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
        trailing: _StatusBadge(isPaid: entry.isPaid),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.isPaid});

  final bool isPaid;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isPaid
            ? AppTheme.greenAccent.withValues(alpha: 0.12)
            : AppTheme.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        isPaid ? 'Paid' : 'Pending',
        style: TextStyle(
          color: isPaid ? AppTheme.greenAccent : AppTheme.error,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
