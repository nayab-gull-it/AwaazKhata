import 'package:flutter/material.dart';
import 'package:khata_app/models/udhaar_entry.dart';
import 'package:khata_app/providers/app_state.dart';
import 'package:khata_app/theme/app_theme.dart';
import 'package:provider/provider.dart';

/// Dialog for manually adding a customer credit (udhaar) entry.
///
/// Mirrors the voice pipeline: the typed customer name is fuzzy-matched
/// against existing unsettled udhaar records via [AppState.findUdhaarMatches],
/// matches are offered as "update existing" choices alongside "create a new
/// record", and saving goes through the same [AppState] methods the voice
/// flow uses.
class AddUdhaarDialog extends StatefulWidget {
  const AddUdhaarDialog({super.key});

  @override
  State<AddUdhaarDialog> createState() => _AddUdhaarDialogState();
}

/// Sentinel radio value for the "create a new record" option.
const _createNew = 'create-new-record';

class _AddUdhaarDialogState extends State<AddUdhaarDialog> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _amountController = TextEditingController();

  /// Unsettled udhaar records whose customer name fuzzy-matches the name
  /// typed so far.
  List<UdhaarEntry> _matches = const [];

  /// Currently chosen radio value: an [UdhaarEntry], [_createNew],
  /// or null while no option is selected.
  Object? _target;

  UdhaarEntry? get _selectedEntry =>
      _target is UdhaarEntry ? _target as UdhaarEntry : null;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  /// Recomputes fuzzy matches as the customer name is typed. A single close
  /// match pre-selects "update existing"; multiple matches start unselected
  /// so the user must pick one.
  void _onNameChanged(String value) {
    final name = value.trim();
    final matches = name.isEmpty
        ? const <UdhaarEntry>[]
        : context.read<AppState>().findUdhaarMatches(name);

    setState(() {
      _matches = matches;
      if (_selectedEntry != null && !_matches.contains(_selectedEntry)) {
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
    final phone = _phoneController.text.trim();
    final amount = double.tryParse(_amountController.text.trim()) ?? 0.0;

    final target = _selectedEntry;
    if (target != null) {
      final newTotal = target.amount + amount;
      appState.updateUdhaar(
        target.copyWith(
          amount: newTotal,
          phoneNumber: phone.isEmpty ? target.phoneNumber : phone,
        ),
      );
      Navigator.of(context).pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text('Updated udhaar for "${target.customerName}" — '
              'new total Rs. ${newTotal.toStringAsFixed(0)}'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    appState.addUdhaar(
      UdhaarEntry(
        id: 'udh-${DateTime.now().millisecondsSinceEpoch}',
        customerName: name,
        phoneNumber: phone,
        amount: amount,
        createdAt: DateTime.now(),
      ),
    );
    Navigator.of(context).pop();
    messenger.showSnackBar(
      SnackBar(
        content: Text('Recorded udhaar for "$name"'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedEntry = _selectedEntry;

    return AlertDialog(
      title: const Text('Add Udhaar Entry'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Customer name'),
              autofocus: true,
              onChanged: _onNameChanged,
            ),
            if (_matches.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text(
                'Matching records found — update or create?',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              if (_matches.length > 1 && _target == null)
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Text(
                    'Pick which record to update, or create a new record',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ),
              RadioGroup<UdhaarEntry>(
                groupValue: selectedEntry,
                onChanged: (value) => setState(() => _target = value),
                child: Column(
                  children: [
                    for (final entry in _matches)
                      RadioListTile<UdhaarEntry>(
                        value: entry,
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        title: Text(entry.customerName),
                        subtitle: Text(
                          'Outstanding Rs. ${_fmt(entry.amount)}',
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
                      '${_nameController.text.trim().isEmpty ? 'this customer' : _nameController.text.trim()}'),
                ),
              ),
              const Divider(height: 24),
            ],
            TextField(
              controller: _phoneController,
              decoration: InputDecoration(
                labelText: 'Phone number',
                helperText: selectedEntry != null
                    ? 'Leave empty to keep ${selectedEntry.phoneNumber}'
                    : null,
              ),
              keyboardType: TextInputType.phone,
            ),
            TextField(
              controller: _amountController,
              decoration: InputDecoration(
                labelText: 'Amount (Rs.)',
                helperText: selectedEntry != null
                    ? 'Adds to current outstanding Rs. '
                        '${_fmt(selectedEntry.amount)}'
                    : null,
              ),
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
