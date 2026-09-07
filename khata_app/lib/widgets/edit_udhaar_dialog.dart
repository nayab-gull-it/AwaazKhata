import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:khata_app/models/udhaar_entry.dart';
import 'package:khata_app/providers/app_state.dart';
import 'package:khata_app/theme/app_theme.dart';
import 'package:khata_app/widgets/date_time_picker_field.dart';
import 'package:provider/provider.dart';

/// Dialog for editing an existing customer credit (udhaar) entry.
///
/// Allows the user to change customer details, amount, description,
/// payment status, and timestamps, and saves through [AppState].
class EditUdhaarDialog extends StatefulWidget {
  const EditUdhaarDialog({required this.entry, super.key});

  final UdhaarEntry entry;

  @override
  State<EditUdhaarDialog> createState() => _EditUdhaarDialogState();
}

class _EditUdhaarDialogState extends State<EditUdhaarDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _amountController;
  late final TextEditingController _descriptionController;
  late DateTime _createdAt;
  late bool _isPaid;
  DateTime? _paidAt;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.entry.customerName);
    _phoneController = TextEditingController(text: widget.entry.phoneNumber);
    _amountController = TextEditingController(
      text: widget.entry.amount.toString(),
    );
    _descriptionController = TextEditingController(
      text: widget.entry.description ?? '',
    );
    _createdAt = widget.entry.createdAt;
    _isPaid = widget.entry.isPaid;
    _paidAt = widget.entry.paidAt;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _save() {
    final updatedEntry = widget.entry.copyWith(
      customerName: _nameController.text.trim(),
      phoneNumber: _phoneController.text.trim(),
      amount: double.tryParse(_amountController.text.trim()) ??
          widget.entry.amount,
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      createdAt: _createdAt,
      isPaid: _isPaid,
      paidAt: _isPaid ? (_paidAt ?? DateTime.now()) : null,
    );

    context.read<AppState>().updateUdhaar(updatedEntry);
    Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Udhaar Entry'),
        content: const Text(
          'Are you sure you want to delete this udhaar entry?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      context.read<AppState>().removeUdhaar(widget.entry.id);
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('d MMM, h:mm a');

    return AlertDialog(
      title: const Text('Edit Udhaar'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Customer Name'),
            ),
            TextField(
              controller: _phoneController,
              decoration: const InputDecoration(labelText: 'Phone Number'),
              keyboardType: TextInputType.phone,
            ),
            TextField(
              controller: _amountController,
              decoration: const InputDecoration(labelText: 'Amount (Rs.)'),
              keyboardType: TextInputType.number,
            ),
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(labelText: 'Description (optional)'),
              maxLines: 2,
            ),
            DateTimePickerField(
              label: 'Recorded on',
              dateTime: _createdAt,
              format: dateFormat,
              onChanged: (value) => setState(() => _createdAt = value),
            ),
            CheckboxListTile(
              title: const Text('Paid'),
              value: _isPaid,
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  _isPaid = value;
                  if (_isPaid && _paidAt == null) {
                    _paidAt = widget.entry.paidAt ?? DateTime.now();
                  }
                });
              },
              contentPadding: EdgeInsets.zero,
            ),
            if (_isPaid)
              DateTimePickerField(
                label: 'Paid at',
                dateTime: _paidAt ?? DateTime.now(),
                format: dateFormat,
                onChanged: (value) => setState(() => _paidAt = value),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _delete,
          style: TextButton.styleFrom(foregroundColor: AppTheme.error),
          child: const Text('Delete'),
        ),
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
