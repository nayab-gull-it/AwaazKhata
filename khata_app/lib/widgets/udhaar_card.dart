import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:khata_app/models/udhaar_entry.dart';
import 'package:khata_app/theme/app_theme.dart';

/// Card widget that displays a single customer credit (udhaar) entry.
///
/// Highlights paid versus pending status and exposes actions to mark
/// an entry as paid, call the customer, or edit the entry.
class UdhaarCard extends StatelessWidget {
  const UdhaarCard({
    required this.entry,
    this.onMarkPaid,
    this.onCall,
    this.onEdit,
    this.onDelete,
    this.onShare,
    super.key,
  });

  final UdhaarEntry entry;
  final VoidCallback? onMarkPaid;
  final VoidCallback? onCall;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onShare;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('d MMM, h:mm a');
    final hasPhone = entry.phoneNumber.trim().isNotEmpty;
    final recentDate = entry.isPaid && entry.paidAt != null
        ? entry.paidAt!
        : entry.createdAt;
    final recentDateLabel = entry.isPaid && entry.paidAt != null
        ? 'Settled on'
        : 'Recorded on';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    entry.customerName,
                    style: theme.textTheme.titleMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                _StatusBadge(isPaid: entry.isPaid),
                if (onEdit != null)
                  IconButton(
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_outlined),
                    tooltip: 'Edit udhaar',
                    color: AppTheme.textSecondary,
                    padding: const EdgeInsets.only(left: 8),
                    constraints: const BoxConstraints(),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              entry.description ?? 'No description',
              style: theme.textTheme.bodyMedium,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _InfoRow(
                    icon: Icons.phone_outlined,
                    text: entry.phoneNumber,
                  ),
                ),
                Expanded(
                  child: _InfoRow(
                    icon: Icons.calendar_today_outlined,
                    text: '$recentDateLabel ${dateFormat.format(recentDate)}',
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Rs. ${entry.amount.toStringAsFixed(0)}',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: entry.isPaid ? AppTheme.textSecondary : AppTheme.navy,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Row(
                  children: [
                    if (!entry.isPaid)
                      TextButton(
                        onPressed: onMarkPaid,
                        child: const Text('Mark Paid'),
                      ),
                    IconButton(
                      onPressed: hasPhone ? onCall : null,
                      icon: const Icon(Icons.call_outlined),
                      tooltip: hasPhone ? 'Call customer' : 'No phone number saved',
                      color: hasPhone ? AppTheme.greenAccent : AppTheme.textSecondary,
                    ),
                    if (onShare != null)
                      IconButton(
                        onPressed: hasPhone ? onShare : null,
                        icon: const Icon(Icons.share_outlined),
                        tooltip: hasPhone
                            ? 'Share bill on WhatsApp'
                            : 'No phone number saved',
                        color:
                            hasPhone ? AppTheme.greenAccent : AppTheme.textSecondary,
                      ),
                    if (onDelete != null)
                      IconButton(
                        onPressed: onDelete,
                        icon: const Icon(Icons.delete_outline),
                        tooltip: 'Delete udhaar',
                        color: AppTheme.error,
                      ),
                  ],
                ),
              ],
            ),
          ],
        ),
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

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: AppTheme.textSecondary,
        ),
        const SizedBox(width: 6),
        Text(
          text,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}
