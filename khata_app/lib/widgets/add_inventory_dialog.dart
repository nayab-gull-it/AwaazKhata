import 'package:flutter/material.dart';
import 'package:khata_app/models/inventory_item.dart';
import 'package:khata_app/providers/app_state.dart';
import 'package:khata_app/theme/app_theme.dart';
import 'package:provider/provider.dart';

/// Dialog for manually adding inventory, as a fallback to voice commands.
///
/// Mirrors the voice pipeline exactly: the typed name is fuzzy-matched
/// against existing items via [AppState.findInventoryMatches], matches are
/// offered as "update existing stock" choices alongside "create a new
/// record", and saving goes through the same [AppState] methods the voice
/// flow uses — so manual entry never creates duplicates.
class AddInventoryDialog extends StatefulWidget {
  const AddInventoryDialog({super.key});

  @override
  State<AddInventoryDialog> createState() => _AddInventoryDialogState();
}

/// Sentinel radio value for the "create a new record" option.
const _createNew = 'create-new-record';

class _AddInventoryDialogState extends State<AddInventoryDialog> {
  final _nameController = TextEditingController();
  final _quantityController = TextEditingController();
  final _purchasePriceController = TextEditingController();
  final _salePriceController = TextEditingController();

  /// Items whose name fuzzy-matches the name typed so far.
  List<InventoryItem> _matches = const [];

  /// Currently chosen radio value: an [InventoryItem], [_createNew],
  /// or null while no option is selected.
  Object? _target;

  InventoryItem? get _selectedItem =>
      _target is InventoryItem ? _target as InventoryItem : null;

  @override
  void dispose() {
    _nameController.dispose();
    _quantityController.dispose();
    _purchasePriceController.dispose();
    _salePriceController.dispose();
    super.dispose();
  }

  /// Recomputes fuzzy matches as the name is typed. A single close match
  /// pre-selects "update existing"; multiple matches start unselected so
  /// the user must pick one — the same rules the voice confirmation
  /// dialog applies.
  void _onNameChanged(String value) {
    final name = value.trim();
    final matches = name.isEmpty
        ? const <InventoryItem>[]
        : context.read<AppState>().findInventoryMatches(name);

    setState(() {
      _matches = matches;
      if (_selectedItem != null && !_matches.contains(_selectedItem)) {
        _target = null;
      }
      if (_matches.length == 1 && _target == null) {
        _target = _matches.single;
      }
    });
  }

  bool get _canSave {
    if (_nameController.text.trim().isEmpty) return false;
    if (_matches.isNotEmpty && _target == null) return false;
    return true;
  }

  void _save() {
    final appState = context.read<AppState>();
    final messenger = ScaffoldMessenger.of(context);
    final name = _nameController.text.trim();
    final quantity = int.tryParse(_quantityController.text.trim());
    final purchasePrice = double.tryParse(
      _purchasePriceController.text.trim(),
    );
    final salePrice = double.tryParse(_salePriceController.text.trim());

    final target = _selectedItem;
    if (target != null) {
      var updated = target;
      if (salePrice != null && salePrice > 0) {
        updated = updated.copyWith(salePrice: salePrice);
      }
      if (purchasePrice != null && purchasePrice > 0) {
        updated = updated.copyWith(purchasePrice: purchasePrice);
      }
      if (quantity != null && quantity > 0) {
        updated = updated.copyWith(quantity: updated.quantity + quantity);
      }
      appState.updateInventoryItem(updated);
      Navigator.of(context).pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text('Updated "${target.name}" — new stock '
              '${updated.quantity} ${updated.unit}'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    appState.addInventoryItem(
      InventoryItem(
        id: 'inv-${DateTime.now().millisecondsSinceEpoch}',
        name: name,
        category: 'General',
        quantity: quantity ?? 1,
        unit: 'pcs',
        purchasePrice: purchasePrice ?? 0.0,
        salePrice: salePrice ?? 0.0,
        createdAt: DateTime.now(),
      ),
    );
    Navigator.of(context).pop();
    messenger.showSnackBar(
      SnackBar(
        content: Text('Added "$name" to inventory'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedItem = _selectedItem;

    return AlertDialog(
      title: const Text('Add Inventory Item'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Item name'),
              autofocus: true,
              onChanged: _onNameChanged,
            ),
            if (_matches.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text(
                'Matching items found — update or create?',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              if (_matches.length > 1 && _target == null)
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Text(
                    'Pick which item to update, or create a new record',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ),
              RadioGroup<InventoryItem>(
                groupValue: selectedItem,
                onChanged: (value) => setState(() => _target = value),
                child: Column(
                  children: [
                    for (final item in _matches)
                      RadioListTile<InventoryItem>(
                        value: item,
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        title: Text(item.name),
                        subtitle: Text(
                          'In stock: ${item.quantity} ${item.unit} · '
                          'Sale Rs. ${_fmt(item.salePrice)}',
                        ),
                      ),
                  ],
                ),
              ),
              RadioGroup<String>(
                groupValue: _target == _createNew ? _createNew : null,
                onChanged: (value) => setState(() => _target = value),
                child: RadioListTile<String>(
                  value: _createNew,
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text('Create new record for '
                      '${_nameController.text.trim().isEmpty ? 'this product' : _nameController.text.trim()}'),
                ),
              ),
              const Divider(height: 24),
            ],
            TextField(
              controller: _quantityController,
              decoration: InputDecoration(
                labelText: 'Quantity',
                helperText: selectedItem != null
                    ? 'Adds to current stock of '
                        '${selectedItem.quantity} ${selectedItem.unit}'
                    : null,
              ),
              keyboardType: TextInputType.number,
            ),
            TextField(
              controller: _purchasePriceController,
              decoration: const InputDecoration(
                labelText: 'Purchase Price (Rs.)',
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _salePriceController,
              decoration: const InputDecoration(labelText: 'Sale Price (Rs.)'),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _canSave ? _save : null,
          child: const Text('Save'),
        ),
      ],
    );
  }

  String _fmt(double value) => value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(2);
}
