import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:khata_app/models/inventory_item.dart';
import 'package:khata_app/providers/app_state.dart';
import 'package:khata_app/widgets/date_time_picker_field.dart';
import 'package:provider/provider.dart';

/// Dialog for editing an existing inventory item.
///
/// Allows the user to change any field, including the creation timestamp,
/// and saves the updated item through [AppState].
class EditInventoryDialog extends StatefulWidget {
  const EditInventoryDialog({required this.item, super.key});

  final InventoryItem item;

  @override
  State<EditInventoryDialog> createState() => _EditInventoryDialogState();
}

class _EditInventoryDialogState extends State<EditInventoryDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _categoryController;
  late final TextEditingController _quantityController;
  late final TextEditingController _unitController;
  late final TextEditingController _purchasePriceController;
  late final TextEditingController _salePriceController;
  late final TextEditingController _minStockController;
  late final TextEditingController _supplierController;
  late DateTime _createdAt;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.item.name);
    _categoryController = TextEditingController(text: widget.item.category);
    _quantityController = TextEditingController(
      text: widget.item.quantity.toString(),
    );
    _unitController = TextEditingController(text: widget.item.unit);
    _purchasePriceController = TextEditingController(
      text: widget.item.purchasePrice.toString(),
    );
    _salePriceController = TextEditingController(
      text: widget.item.salePrice.toString(),
    );
    _minStockController = TextEditingController(
      text: widget.item.minStockLevel.toString(),
    );
    _supplierController = TextEditingController(
      text: widget.item.supplierName ?? '',
    );
    _createdAt = widget.item.createdAt;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _categoryController.dispose();
    _quantityController.dispose();
    _unitController.dispose();
    _purchasePriceController.dispose();
    _salePriceController.dispose();
    _minStockController.dispose();
    _supplierController.dispose();
    super.dispose();
  }

  void _save() {
    final updatedItem = widget.item.copyWith(
      name: _nameController.text.trim(),
      category: _categoryController.text.trim(),
      quantity: int.tryParse(_quantityController.text.trim()) ?? widget.item.quantity,
      unit: _unitController.text.trim(),
      purchasePrice: double.tryParse(_purchasePriceController.text.trim()) ??
          widget.item.purchasePrice,
      salePrice: double.tryParse(_salePriceController.text.trim()) ??
          widget.item.salePrice,
      minStockLevel: int.tryParse(_minStockController.text.trim()) ??
          widget.item.minStockLevel,
      supplierName: _supplierController.text.trim().isEmpty
          ? null
          : _supplierController.text.trim(),
      createdAt: _createdAt,
    );

    context.read<AppState>().updateInventoryItem(updatedItem);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('d MMM, h:mm a');

    return AlertDialog(
      title: const Text('Edit Inventory Item'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            TextField(
              controller: _categoryController,
              decoration: const InputDecoration(labelText: 'Category'),
            ),
            TextField(
              controller: _quantityController,
              decoration: const InputDecoration(labelText: 'Quantity'),
              keyboardType: TextInputType.number,
            ),
            TextField(
              controller: _unitController,
              decoration: const InputDecoration(labelText: 'Unit'),
            ),
            TextField(
              controller: _purchasePriceController,
              decoration: const InputDecoration(labelText: 'Purchase Price'),
              keyboardType: TextInputType.number,
            ),
            TextField(
              controller: _salePriceController,
              decoration: const InputDecoration(labelText: 'Sale Price'),
              keyboardType: TextInputType.number,
            ),
            TextField(
              controller: _minStockController,
              decoration: const InputDecoration(labelText: 'Min Stock Level'),
              keyboardType: TextInputType.number,
            ),
            TextField(
              controller: _supplierController,
              decoration: const InputDecoration(labelText: 'Supplier (optional)'),
            ),
            DateTimePickerField(
              label: 'Added on',
              dateTime: _createdAt,
              format: dateFormat,
              onChanged: (value) => setState(() => _createdAt = value),
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
          onPressed: _save,
          child: const Text('Save'),
        ),
      ],
    );
  }
}
