import 'package:flutter/material.dart';
import 'package:khata_app/models/inventory_item.dart';
import 'package:khata_app/providers/app_state.dart';
import 'package:khata_app/widgets/add_inventory_dialog.dart';
import 'package:khata_app/widgets/edit_inventory_dialog.dart';
import 'package:khata_app/widgets/item_card.dart';
import 'package:provider/provider.dart';

/// Screen that lists all inventory items.
///
/// Reads inventory data from [AppState] and renders each item through
/// [ItemCard], with a search bar that filters items by name, an edit
/// action that opens [EditInventoryDialog], and a "+" button that opens
/// [AddInventoryDialog] for manual entry.
class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _editItem(InventoryItem item) {
    showDialog<void>(
      context: context,
      builder: (_) => EditInventoryDialog(item: item),
    );
  }

  void _addItem() {
    showDialog<void>(
      context: context,
      builder: (_) => const AddInventoryDialog(),
    );
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() => _query = '');
  }

  @override
  Widget build(BuildContext context) {
    final inventory = context.watch<AppState>().inventory;
    final query = _query.trim().toLowerCase();
    final visibleItems = query.isEmpty
        ? inventory
        : inventory
            .where((item) => item.name.toLowerCase().contains(query))
            .toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search items by name',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: _clearSearch,
                      tooltip: 'Clear search',
                    ),
            ),
            onChanged: (value) => setState(() => _query = value),
          ),
        ),
        Expanded(
          child: Stack(
            children: [
              if (visibleItems.isEmpty)
                _EmptyState(
                  icon: query.isEmpty
                      ? Icons.inventory_2_outlined
                      : Icons.search_off,
                  message: query.isEmpty
                      ? 'No inventory items yet.\n'
                          'Add items by voice or manually.'
                      : 'No items match "${_query.trim()}".\n'
                          'Try a different name or clear the search.',
                )
              else
                ListView.builder(
                  padding: const EdgeInsets.only(top: 12, bottom: 100),
                  itemCount: visibleItems.length,
                  itemBuilder: (context, index) {
                    final item = visibleItems[index];
                    return ItemCard(
                      item: item,
                      onEdit: () => _editItem(item),
                    );
                  },
                ),
              Positioned(
                right: 16,
                bottom: 16,
                child: FloatingActionButton(
                  onPressed: _addItem,
                  tooltip: 'Add inventory item',
                  child: const Icon(Icons.add),
                ),
              ),
            ],
          ),
        ),
      ],
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
