import 'package:flutter/material.dart';
import 'package:khata_app/models/inventory_item.dart';
import 'package:khata_app/providers/app_state.dart';
import 'package:khata_app/widgets/edit_inventory_dialog.dart';
import 'package:khata_app/widgets/item_card.dart';
import 'package:provider/provider.dart';

/// Screen that lists all inventory items.
///
/// Reads inventory data from [AppState] and renders each item through
/// [ItemCard], with an edit action that opens [EditInventoryDialog].
class InventoryScreen extends StatelessWidget {
  const InventoryScreen({super.key});

  void _editItem(BuildContext context, InventoryItem item) {
    showDialog<void>(
      context: context,
      builder: (_) => EditInventoryDialog(item: item),
    );
  }

  @override
  Widget build(BuildContext context) {
    final inventory = context.watch<AppState>().inventory;

    if (inventory.isEmpty) {
      return const _EmptyState(
        icon: Icons.inventory_2_outlined,
        message: 'No inventory items yet.\nAdd items by voice or manually.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(top: 12, bottom: 100),
      itemCount: inventory.length,
      itemBuilder: (context, index) {
        final item = inventory[index];
        return ItemCard(
          item: item,
          onEdit: () => _editItem(context, item),
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Theme.of(context).hintColor),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ],
      ),
    );
  }
}
