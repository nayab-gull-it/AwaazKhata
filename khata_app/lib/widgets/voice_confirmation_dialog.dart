import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:khata_app/models/inventory_item.dart';
import 'package:khata_app/models/parsed_action.dart';
import 'package:khata_app/models/task.dart';
import 'package:khata_app/models/udhaar_entry.dart';
import 'package:khata_app/theme/app_theme.dart';
import 'package:khata_app/widgets/date_time_picker_field.dart';

/// Outcome of a confirmed voice command.
///
/// Carries the (possibly edited) [action] plus the existing record the user
/// chose to update, if any. Null targets mean "create a new record".
class VoiceConfirmationResult {
  const VoiceConfirmationResult({
    required this.action,
    this.udhaarTarget,
    this.inventoryTarget,
  });

  final ParsedAction action;

  /// Existing udhaar entry to update, when the user picked one.
  final UdhaarEntry? udhaarTarget;

  /// Existing inventory item to update, when the user picked one.
  final InventoryItem? inventoryTarget;
}

/// Confirmation dialog shown after the backend parses a voice command.
///
/// Displays the parsed action type, target, and item/customer details.
/// When existing records closely match the spoken name, the dialog asks
/// whether to update one of them or create a new record — with several
/// close matches the user must pick one explicitly. Numeric fields
/// (quantity, amount, prices) are editable because speech recognition
/// often mishears numbers. Returns the confirmed [VoiceConfirmationResult]
/// on OK, or null on Cancel.
class VoiceConfirmationDialog extends StatefulWidget {
  const VoiceConfirmationDialog({
    required this.action,
    this.udhaarCandidates = const [],
    this.inventoryCandidates = const [],
    super.key,
  });

  final ParsedAction action;

  /// Unpaid udhaar entries whose customer name matches the spoken name.
  final List<UdhaarEntry> udhaarCandidates;

  /// Inventory items whose name matches the spoken product name.
  final List<InventoryItem> inventoryCandidates;

  /// Convenience method to show this dialog and return the result.
  static Future<VoiceConfirmationResult?> show(
    BuildContext context,
    ParsedAction action, {
    List<UdhaarEntry> udhaarCandidates = const [],
    List<InventoryItem> inventoryCandidates = const [],
  }) {
    return showDialog<VoiceConfirmationResult>(
      context: context,
      builder: (_) => VoiceConfirmationDialog(
        action: action,
        udhaarCandidates: udhaarCandidates,
        inventoryCandidates: inventoryCandidates,
      ),
    );
  }

  @override
  State<VoiceConfirmationDialog> createState() =>
      _VoiceConfirmationDialogState();
}

/// Sentinel radio value for the "create a new record" option.
const _createNew = 'create-new-record';

class _VoiceConfirmationDialogState extends State<VoiceConfirmationDialog> {
  late final TextEditingController _quantityController;
  late final TextEditingController _amountController;
  late final TextEditingController _purchasePriceController;
  late final TextEditingController _salePriceController;
  late final TextEditingController _taskTitleController;

  /// Currently chosen radio value: an [UdhaarEntry], an [InventoryItem],
  /// [_createNew], or null while no option is selected.
  Object? _target;

  /// Editable task due date, if the user set one.
  DateTime? _taskDueAt;

  /// Editable task priority.
  late TaskPriority _taskPriority;

  UdhaarEntry? get _selectedUdhaar =>
      _target is UdhaarEntry ? _target as UdhaarEntry : null;

  InventoryItem? get _selectedInventory =>
      _target is InventoryItem ? _target as InventoryItem : null;

  bool get _isReduce => widget.action.type == VoiceActionType.reduceUdhaar;

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
    _taskTitleController = TextEditingController(
      text: widget.action.title ?? '',
    );
    _taskDueAt = widget.action.dueAt;
    _taskPriority = widget.action.priority;

    // A single close match pre-selects "update existing"; multiple matches
    // start unselected so the user must pick one.
    if (widget.udhaarCandidates.length == 1) {
      _target = widget.udhaarCandidates.single;
    } else if (widget.inventoryCandidates.length == 1) {
      _target = widget.inventoryCandidates.single;
    }
    if (_selectedInventory != null) {
      _prefillPricesFrom(_selectedInventory!);
    }
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _amountController.dispose();
    _purchasePriceController.dispose();
    _salePriceController.dispose();
    _taskTitleController.dispose();
    super.dispose();
  }

  /// When updating an item and the transcript didn't mention prices, show
  /// the item's current prices instead of the backend's zero defaults.
  void _prefillPricesFrom(InventoryItem item) {
    if ((widget.action.purchasePrice ?? 0) <= 0) {
      _purchasePriceController.text = item.purchasePrice.toStringAsFixed(0);
    }
    if ((widget.action.salePrice ?? 0) <= 0) {
      _salePriceController.text = item.salePrice.toStringAsFixed(0);
    }
  }

  void _selectTarget(Object? target) {
    setState(() => _target = target);
    final item = target is InventoryItem ? target : null;
    if (item != null) {
      _prefillPricesFrom(item);
    } else if (target == _createNew) {
      _purchasePriceController.text =
          widget.action.purchasePrice?.toString() ?? '';
      _salePriceController.text = widget.action.salePrice?.toString() ?? '';
    }
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

    if (widget.action.type == VoiceActionType.addUdhaar ||
        widget.action.type == VoiceActionType.reduceUdhaar) {
      final amt = double.tryParse(_amountController.text.trim());
      if (amt != null) overrides['amount'] = amt;
    }

    if (widget.action.type == VoiceActionType.addTask) {
      final title = _taskTitleController.text.trim();
      if (title.isNotEmpty) overrides['title'] = title;
      if (_taskDueAt != null) overrides['due_at'] = _taskDueAt!.toIso8601String();
      overrides['priority'] = _taskPriority.name;
    }

    return widget.action.copyWithField(overrides);
  }

  /// Whether the current selection is complete enough to confirm.
  bool get _canConfirm {
    switch (widget.action.type) {
      case VoiceActionType.addUdhaar:
        return widget.udhaarCandidates.isEmpty || _target != null;
      case VoiceActionType.reduceUdhaar:
        return _selectedUdhaar != null;
      case VoiceActionType.addInventory:
        return widget.inventoryCandidates.isEmpty || _target != null;
      default:
        return true;
    }
  }

  void _confirm() {
    Navigator.of(context).pop(
      VoiceConfirmationResult(
        action: _buildConfirmedAction(),
        udhaarTarget: _selectedUdhaar,
        inventoryTarget: _selectedInventory,
      ),
    );
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
        if (action.type != VoiceActionType.unknown && _canConfirm)
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
      VoiceActionType.reduceUdhaar => _buildUdhaarBody(action),
      VoiceActionType.addTask => _buildTaskBody(action),
      VoiceActionType.queryBalance => _buildQueryBalanceBody(action),
      VoiceActionType.queryItemStock ||
      VoiceActionType.queryItemPrice ||
      VoiceActionType.queryLowStock ||
      VoiceActionType.queryInventoryCount ||
      VoiceActionType.queryTransactionsByDate =>
        _buildQueryPlaceholderBody(action),
      VoiceActionType.navigate => _buildNavigateBody(action),
      VoiceActionType.unknown => _buildUnknownBody(),
    };
  }

  /// Query actions are answered by VoiceAnswerDialog before this dialog is
  /// ever shown; this body only keeps the switch exhaustive.
  Widget _buildQueryPlaceholderBody(ParsedAction action) {
    final target = action.name ?? action.customerName ?? '—';
    final queryLabel = switch (action.type) {
      VoiceActionType.queryItemStock => 'Stock of',
      VoiceActionType.queryItemPrice => 'Price of',
      VoiceActionType.queryLowStock => 'Items low on stock',
      VoiceActionType.queryInventoryCount => 'Total item count',
      _ => 'Query',
    };
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ReadOnlyField(label: 'Query', value: '$queryLabel $target'),
      ],
    );
  }

  Widget _buildInventoryBody(ParsedAction action) {
    final candidates = widget.inventoryCandidates;
    final selected = _selectedInventory;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (candidates.isNotEmpty) ...[
          const Text(
            'Matching items found — update or create?',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          RadioGroup<InventoryItem>(
            groupValue: selected,
            onChanged: (value) => _selectTarget(value),
            child: Column(
              children: candidates
                  .map(
                    (item) => RadioListTile<InventoryItem>(
                      value: item,
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: Text(item.name),
                      subtitle: Text(
                        'In stock: ${item.quantity} ${item.unit} · '
                        'Sale Rs. ${_fmt(item.salePrice)}',
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          RadioGroup<String>(
            groupValue: _target == _createNew ? _createNew : null,
            onChanged: (value) => _selectTarget(value),
            child: RadioListTile<String>(
              value: _createNew,
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(
                  'Create new record for ${action.name ?? 'this product'}'),
            ),
          ),
          const Divider(height: 24),
        ],
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
    final candidates = widget.udhaarCandidates;
    final amount = double.tryParse(_amountController.text.trim()) ?? 0;
    final selected = _selectedUdhaar;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (candidates.isNotEmpty) ...[
          Text(
            _isReduce
                ? 'Which record is this payment for?'
                : 'Matching records found — update or create?',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          RadioGroup<UdhaarEntry>(
            groupValue: selected,
            onChanged: (value) => _selectTarget(value),
            child: Column(
              children: candidates
                  .map(
                    (entry) => RadioListTile<UdhaarEntry>(
                      value: entry,
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: Text(entry.customerName),
                      subtitle: selected == entry
                          ? Text(
                              _isReduce
                                  ? 'Current Rs. ${_fmt(entry.amount)} → '
                                      'New balance Rs. '
                                      '${_fmt((entry.amount - amount).clamp(0.0, double.infinity))}'
                                  : 'Current Rs. ${_fmt(entry.amount)} → '
                                      'New total Rs. '
                                      '${_fmt(entry.amount + amount)}',
                              style: TextStyle(
                                color: AppTheme.greenAccent,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            )
                          : Text('Outstanding Rs. ${_fmt(entry.amount)}'),
                    ),
                  )
                  .toList(),
            ),
          ),
          if (!_isReduce)
            RadioGroup<String>(
              groupValue: _target == _createNew ? _createNew : null,
              onChanged: (value) => _selectTarget(value),
              child: RadioListTile<String>(
                value: _createNew,
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text('Create new record for '
                    '${action.customerName ?? 'this customer'}'),
              ),
            ),
          const Divider(height: 24),
        ],
        if (_isReduce && candidates.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              'No matching udhaar record found for this name. '
              'A payment can only be applied to an existing record.',
              style: TextStyle(color: AppTheme.error, fontSize: 12),
            ),
          ),
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
          decoration: InputDecoration(
            labelText: _isReduce ? 'Amount Paid (Rs.)' : 'Amount (Rs.)',
            border: const OutlineInputBorder(),
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: (_) => setState(() {}),
        ),
      ],
    );
  }

  String _fmt(double value) =>
      value == value.roundToDouble() ? value.toStringAsFixed(0) : value.toStringAsFixed(2);

  Widget _buildTaskBody(ParsedAction action) {
    final dateFormat = DateFormat('d MMM, h:mm a');
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _taskTitleController,
          decoration: const InputDecoration(
            labelText: 'Task name',
            border: OutlineInputBorder(),
          ),
          textInputAction: TextInputAction.done,
        ),
        const SizedBox(height: 12),
        DateTimePickerField(
          label: _taskDueAt == null ? 'Add reminder time (optional)' : 'Due',
          dateTime: _taskDueAt,
          format: dateFormat,
          allowClear: true,
          onChanged: (value) => setState(() => _taskDueAt = value),
        ),
        const SizedBox(height: 12),
        InputDecorator(
          decoration: const InputDecoration(
            labelText: 'Priority',
            border: OutlineInputBorder(),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<TaskPriority>(
              value: _taskPriority,
              isDense: true,
              items: TaskPriority.values
                  .map(
                    (p) => DropdownMenuItem(
                      value: p,
                      child: Text(
                          p.name[0].toUpperCase() + p.name.substring(1)),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) setState(() => _taskPriority = value);
              },
            ),
          ),
        ),
        if (action.description != null) ...[
          const SizedBox(height: 12),
          _ReadOnlyField(label: 'Description', value: action.description!),
        ],
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
      VoiceActionType.reduceUdhaar => Icons.payments_outlined,
      VoiceActionType.addTask => Icons.check_circle_outline,
      VoiceActionType.queryBalance => Icons.balance_outlined,
      VoiceActionType.queryItemStock => Icons.inventory_2_outlined,
      VoiceActionType.queryItemPrice => Icons.local_offer_outlined,
      VoiceActionType.queryLowStock => Icons.warning_amber_outlined,
      VoiceActionType.queryInventoryCount => Icons.calculate_outlined,
      VoiceActionType.queryTransactionsByDate => Icons.history_outlined,
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
