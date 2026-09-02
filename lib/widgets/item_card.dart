import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:khata_app/models/inventory_item.dart';
import 'package:khata_app/theme/app_theme.dart';

/// Card widget that displays a single inventory item.
///
/// Shows stock quantity, pricing, creation timestamp, a low-stock warning,
/// and an edit action when applicable.
class ItemCard extends StatelessWidget {
  const ItemCard({
    required this.item,
    this.onTap,
    this.onEdit,
    super.key,
  });

  final InventoryItem item;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('d MMM, h:mm a');

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
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
                      item.name,
                      style: theme.textTheme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (item.isLowStock)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.error.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'Low Stock',
                        style: TextStyle(
                          color: AppTheme.error,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  if (onEdit != null)
                    IconButton(
                      onPressed: onEdit,
                      icon: const Icon(Icons.edit_outlined),
                      tooltip: 'Edit item',
                      color: AppTheme.textSecondary,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '${item.category} • ${item.quantity} ${item.unit} in stock',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _PriceColumn(
                    label: 'Cost',
                    value: 'Rs. ${item.purchasePrice.toStringAsFixed(0)}',
                  ),
                  const SizedBox(width: 24),
                  _PriceColumn(
                    label: 'Sale',
                    value: 'Rs. ${item.salePrice.toStringAsFixed(0)}',
                  ),
                  const SizedBox(width: 24),
                  _PriceColumn(
                    label: 'Profit',
                    value: 'Rs. ${item.profitPerUnit.toStringAsFixed(0)}',
                    valueColor: AppTheme.greenAccent,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Added on ${dateFormat.format(item.createdAt)}',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PriceColumn extends StatelessWidget {
  const _PriceColumn({
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}
