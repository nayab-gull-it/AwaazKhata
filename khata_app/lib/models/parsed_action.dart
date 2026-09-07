import 'package:khata_app/models/task.dart';

/// Structured action returned by the backend after parsing a voice command.
///
/// The backend (not the Flutter app) runs Qwen and decides what the user
/// intended. The Flutter side simply renders the result for confirmation
/// and then applies it to [AppState].
class ParsedAction {
  const ParsedAction({
    required this.type,
    required this.fields,
  });

  /// What the user intended to do.
  final VoiceActionType type;

  /// Named fields extracted by the backend (name, quantity, amount, etc.).
  ///
  /// Values may be strings, numbers, or null. The confirmation dialog reads
  /// from this map and lets the user correct numeric fields before applying.
  final Map<String, dynamic> fields;

  /// Builds a [ParsedAction] from the JSON returned by `/parse-command`.
  ///
  /// If the backend response doesn't match the expected shape, returns a
  /// [VoiceActionType.unknown] action instead of throwing.
  factory ParsedAction.fromJson(Map<String, dynamic> json) {
    final rawAction = json['action'] as String? ?? '';
    final type = VoiceActionType.fromString(rawAction);

    final fields = Map<String, dynamic>.from(json);
    fields.remove('action');

    return ParsedAction(type: type, fields: fields);
  }

  /// Convenience getter for the `name` field.
  String? get name => fields['name'] as String?;

  /// Convenience getter for the `quantity` field as an int.
  int? get quantity {
    final raw = fields['quantity'];
    if (raw == null) return null;
    if (raw is int) return raw;
    if (raw is double) return raw.toInt();
    if (raw is String) return int.tryParse(raw);
    return null;
  }

  /// Convenience getter for the `amount` field as a double.
  double? get amount {
    final raw = fields['amount'];
    if (raw == null) return null;
    if (raw is double) return raw;
    if (raw is int) return raw.toDouble();
    if (raw is String) return double.tryParse(raw);
    return null;
  }

  /// Convenience getter for the `unit` field.
  String? get unit => fields['unit'] as String?;

  /// Convenience getter for the `category` field.
  String? get category => fields['category'] as String?;

  /// Convenience getter for the `customer_name` field.
  String? get customerName => fields['customer_name'] as String?;

  /// Convenience getter for the `phone_number` field.
  String? get phoneNumber => fields['phone_number'] as String?;

  /// Convenience getter for the `description` field.
  String? get description => fields['description'] as String?;

  /// Convenience getter for the `due_at` field as a [DateTime].
  DateTime? get dueAt {
    final raw = fields['due_at'];
    if (raw == null) return null;
    if (raw is DateTime) return raw;
    if (raw is String) return DateTime.tryParse(raw);
    return null;
  }

  /// Convenience getter for the `title` field.
  String? get title => fields['title'] as String?;

  /// Convenience getter for the `priority` field as a [TaskPriority].
  TaskPriority get priority {
    final raw = fields['priority'];
    if (raw == null) return TaskPriority.normal;
    final normalized = raw.toString().toLowerCase();
    return switch (normalized) {
      'high' || 'urgent' => TaskPriority.high,
      'low' => TaskPriority.low,
      _ => TaskPriority.normal,
    };
  }

  /// Convenience getter for the `purchase_price` field as a double.
  double? get purchasePrice {
    final raw = fields['purchase_price'];
    if (raw == null) return null;
    if (raw is double) return raw;
    if (raw is int) return raw.toDouble();
    if (raw is String) return double.tryParse(raw);
    return null;
  }

  /// Convenience getter for the `sale_price` field as a double.
  double? get salePrice {
    final raw = fields['sale_price'];
    if (raw == null) return null;
    if (raw is double) return raw;
    if (raw is int) return raw.toDouble();
    if (raw is String) return double.tryParse(raw);
    return null;
  }

  /// Convenience getter for the `target_tab` field (used by navigate actions).
  String? get targetTab => fields['target_tab'] as String?;

  /// Convenience getter for the `direction` field (used by query_balance).
  ///
  /// Either "outgoing" (customer owes the shop) or "incoming" (shop owes the
  /// customer). Defaults to "outgoing" when the backend omits it.
  String? get direction => fields['direction'] as String?;

  /// Returns a copy of this action with one or more fields overridden.
  ParsedAction copyWithField(Map<String, dynamic> overrides) {
    return ParsedAction(
      type: type,
      fields: {...fields, ...overrides},
    );
  }

  /// Whether this action asks for information instead of changing data.
  ///
  /// Query actions are answered directly with a read-only dialog instead of
  /// going through the edit/confirm flow.
  bool get isQuery =>
      type == VoiceActionType.queryBalance ||
      type == VoiceActionType.queryItemStock ||
      type == VoiceActionType.queryItemPrice ||
      type == VoiceActionType.queryLowStock ||
      type == VoiceActionType.queryInventoryCount ||
      type == VoiceActionType.queryTransactionsByDate;

  /// The requested transaction date (YYYY-MM-DD) for date-wise queries.
  DateTime? get queryDate {
    final raw = fields['date'];
    if (raw == null) return null;
    if (raw is DateTime) return raw;
    if (raw is String) return DateTime.tryParse(raw);
    return null;
  }
}

/// Types of action the backend can parse from a voice command.
enum VoiceActionType {
  addInventory,
  addUdhaar,
  reduceUdhaar,
  addTask,
  queryBalance,
  queryItemStock,
  queryItemPrice,
  queryLowStock,
  queryInventoryCount,
  queryTransactionsByDate,
  navigate,
  unknown;

  static VoiceActionType fromString(String raw) {
    return switch (raw.toLowerCase()) {
      'add_inventory' => addInventory,
      'add_udhaar' => addUdhaar,
      'reduce_udhaar' => reduceUdhaar,
      'add_task' => addTask,
      'query_balance' => queryBalance,
      'query_item_stock' => queryItemStock,
      'query_item_price' => queryItemPrice,
      'query_low_stock' => queryLowStock,
      'query_inventory_count' => queryInventoryCount,
      'query_transactions_by_date' => queryTransactionsByDate,
      'navigate' => navigate,
      _ => unknown,
    };
  }

  /// Human-readable label for the confirmation dialog.
  String get label => switch (this) {
        addInventory => 'Add Inventory Item',
        addUdhaar => 'Record Udhaar',
        reduceUdhaar => 'Reduce Udhaar (Payment)',
        addTask => 'Create Task',
        queryBalance => 'Look Up Balance',
        queryItemStock => 'Item Stock',
        queryItemPrice => 'Item Price',
        queryLowStock => 'Low Stock Items',
        queryInventoryCount => 'Inventory Count',
        queryTransactionsByDate => 'Transactions by Date',
        navigate => 'Navigate',
        unknown => 'Unrecognized Command',
      };
}
