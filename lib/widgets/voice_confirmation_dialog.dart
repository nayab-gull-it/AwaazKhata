import 'package:flutter/material.dart';
import 'package:khata_app/models/parsed_action.dart';
import 'package:khata_app/theme/app_theme.dart';

/// Confirmation dialog shown after the backend parses a voice command.
///
/// Displays the parsed action type, target, and item/customer details.
/// Numeric fields (quantity, amount, prices) are editable because speech
/// recognition often mishears numbers. Returns the confirmed (possibly
/// modified) [ParsedAction] on OK, or null on Cancel.
class VoiceConfirmationDialog extends StatefulWidget {
  const VoiceConfirmationDialog({required this.action, super.key});

  final ParsedAction action;

  /// Convenience method to show this dialog and return the result.
  static Future<ParsedAction?> show(
    BuildContext context,
    ParsedAction action,
  ) {
    return showDialog<ParsedAction>(
      context: context,
      builder: (_) => VoiceConfirmationDialog(action: action),
    );
  }

  @override
  State<VoiceConfirmationDialog> createState() =>
      _VoiceConfirmationDialogState();
}

class _VoiceConfirmationDialogState extends State<VoiceConfirmationDialog> {
  late final TextEditingController _quantityController;
  late final TextEditingController _amountController;
  late final TextEditingController _purchasePriceController;
  late final TextEditingController _salePriceController;

  @override
  void initState() {
    super.initState();
    _quantityController = TextEditingController(
      text: widget.action.quantity?.toString() ?? '',
    );
    _amountController = TextEditingController(
      text: widget.action.amount?.toString() ?? '',
    );
    _purchasePriceController = TextEditingController(
      text: widget.action.purchasePrice?.toString() ?? '',
    );
    _salePriceController = TextEditingController(
      text: widget.action.salePrice?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _amountController.dispose();
    _purchasePriceController.dispose();
    _salePriceController.dispose();
    super.dispose();
  }

  /// Builds the confirmed action with any user edits applied.
  ParsedAction _buildConfirmedAction() {
    final overrides = <String, dynamic>{};

    if (widget.action.type == VoiceActionType.addInventory) {
      final qty = int.tryParse(_quantityController.text.trim());
      if (qty != null) overrides['quantity'] = qty;
      final pp = double.tryParse(_purchasePriceController.text.trim());
      if (pp != null) overrides['purchase_price'] = pp;
      final sp = double.tryParse(_salePriceController.text.trim());
      if (sp != null) overrides['sale_price'] = sp;
    }

    if (widget.action.type == VoiceActionType.addUdhaar) {
      final amt = double.tryParse(_amountController.text.trim());
      if (amt != null) overrides['amount'] = amt;
    }

    return widget.action.copyWithField(overrides);
  }

  void _confirm() {
    Navigator.of(context).pop(_buildConfirmedAction());
  }

  void _cancel() {
    Navigator.of(context).pop(null);
  }

  @override
  Widget build(BuildContext context) {
    final action = widget.action;

    return AlertDialog(
      title: Row(
        children: [
          Icon(_iconForAction(action.type), color: AppTheme.navy),
          const SizedBox(width: 8),
          Expanded(child: Text(action.type.label)),
        ],
      ),
      content: SingleChildScrollView(
        child: _buildBody(action),
      ),
      actions: [
        TextButton(
          onPressed: _cancel,
          child: const Text('Cancel'),
        ),
        if (action.type != VoiceActionType.unknown)
          ElevatedButton(
            onPressed: _confirm,
            child: Text(
              action.type == VoiceActionType.navigate
                  ? 'Go'
                  : action.type == VoiceActionType.queryBalance
                      ? 'Look Up'
                      : 'Confirm',
            ),
          ),
      ],
    );
  }

  Widget _buildBody(ParsedAction action) {
    return switch (action.type) {
      VoiceActionType.addInventory => _buildInventoryBody(action),
      VoiceActionType.addUdhaar => _buildUdhaarBody(action),
      VoiceActionType.addTask => _buildTaskBody(action),
      VoiceActionType.queryBalance => _buildQueryBalanceBody(action),
      VoiceActionType.navigate => _buildNavigateBody(action),
      VoiceActionType.unknown => _buildUnknownBody(),
    };
  }

  Widget _buildInventoryBody(ParsedAction action) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ReadOnlyField(label: 'Item', value: action.name ?? '—'),
        _ReadOnlyField(label: 'Category', value: action.category ?? '—'),
        _ReadOnlyField(label: 'Unit', value: action.unit ?? 'pcs'),
        const SizedBox(height: 12),
        const Text(
          'Edit numbers if needed:',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _quantityController,
          decoration: const InputDecoration(
            labelText: 'Quantity',
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _purchasePriceController,
          decoration: const InputDecoration(
            labelText: 'Purchase Price (Rs.)',
            border: OutlineInputBorder(),
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _salePriceController,
          decoration: const InputDecoration(
            labelText: 'Sale Price (Rs.)',
            border: OutlineInputBorder(),
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        ),
      ],
    );
  }

  Widget _buildUdhaarBody(ParsedAction action) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ReadOnlyField(
          label: 'Customer',
          value: action.customerName ?? '—',
        ),
        _ReadOnlyField(
          label: 'Phone',
          value: action.phoneNumber ?? '—',
        ),
        if (action.description != null)
          _ReadOnlyField(label: 'Note', value: action.description!),
        const SizedBox(height: 12),
        const Text(
          'Edit amount if needed:',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _amountController,
          decoration: const InputDecoration(
            labelText: 'Amount (Rs.)',
            border: OutlineInputBorder(),
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        ),
      ],
    );
  }

  Widget _buildTaskBody(ParsedAction action) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ReadOnlyField(label: 'Title', value: action.title ?? '—'),
        if (action.description != null)
          _ReadOnlyField(label: 'Description', value: action.description!),
      ],
    );
  }

  Widget _buildNavigateBody(ParsedAction action) {
    final tabLabel = _tabLabel(action.targetTab);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Navigate to $tabLabel?',
          style: const TextStyle(fontSize: 16),
        ),
      ],
    );
  }

  Widget _buildQueryBalanceBody(ParsedAction action) {
    final name = action.customerName ?? 'Unknown';
    final directionLabel =
        action.direction == 'incoming' ? 'we owe them' : 'they owe us';
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Look up balance for $name?',
          style: const TextStyle(fontSize: 16),
        ),
        const SizedBox(height: 8),
        Text(
          'Direction: $directionLabel',
          style: const TextStyle(fontSize: 13, color: Colors.black54),
        ),
      ],
    );
  }

  Widget _buildUnknownBody() {
    return const Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.warning_amber_outlined, color: AppTheme.error, size: 32),
        SizedBox(height: 8),
        Text(
          "Couldn't understand that command. "
          'Try rephrasing or check that the backend is running.',
        ),
      ],
    );
  }

  IconData _iconForAction(VoiceActionType type) {
    return switch (type) {
      VoiceActionType.addInventory => Icons.inventory_2_outlined,
      VoiceActionType.addUdhaar => Icons.account_balance_wallet_outlined,
      VoiceActionType.addTask => Icons.check_circle_outline,
      VoiceActionType.queryBalance => Icons.balance_outlined,
      VoiceActionType.navigate => Icons.open_in_new,
      VoiceActionType.unknown => Icons.help_outline,
    };
  }

  String _tabLabel(String? targetTab) {
    return switch (targetTab?.toLowerCase()) {
      'inventory' => 'Inventory',
      'tasks' => 'Tasks',
      'udhaar' => 'Udhaar',
      _ => targetTab ?? 'Home',
    };
  }
}

class _ReadOnlyField extends StatelessWidget {
  const _ReadOnlyField({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
