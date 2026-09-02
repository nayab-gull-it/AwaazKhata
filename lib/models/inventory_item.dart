/// Represents a single product or stock item in the shop.
///
/// Keeps business-relevant fields strongly typed so the rest of the app
/// can rely on autocompletion and null-safety rather than dynamic maps.
class InventoryItem {
  const InventoryItem({
    required this.id,
    required this.name,
    required this.category,
    required this.quantity,
    required this.unit,
    required this.purchasePrice,
    required this.salePrice,
    this.minStockLevel = 0,
    this.supplierName,
    required this.createdAt,
  });

  /// Unique identifier for this inventory item.
  final String id;

  /// Display name of the product (e.g. "Dalda Cooking Oil 1L").
  final String name;

  /// Broad grouping used for filtering and reporting.
  final String category;

  /// Current stock count. Use [unit] for the unit of measurement.
  final int quantity;

  /// Unit in which the item is measured (pieces, kg, liter, dozen, etc.).
  final String unit;

  /// Cost price per unit in Pakistani Rupees.
  final double purchasePrice;

  /// Selling price per unit in Pakistani Rupees.
  final double salePrice;

  /// Threshold below which the shopkeeper should restock.
  final int minStockLevel;

  /// Optional name of the supplier for restock reminders.
  final String? supplierName;

  /// Date and time when this item was added to inventory.
  final DateTime createdAt;

  /// True when available stock has fallen at or below the minimum level.
  bool get isLowStock => quantity <= minStockLevel;

  /// Profit margin per unit.
  double get profitPerUnit => salePrice - purchasePrice;

  /// Creates a copy with selected fields updated, preserving immutability.
  InventoryItem copyWith({
    String? id,
    String? name,
    String? category,
    int? quantity,
    String? unit,
    double? purchasePrice,
    double? salePrice,
    int? minStockLevel,
    String? supplierName,
    DateTime? createdAt,
  }) {
    return InventoryItem(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      purchasePrice: purchasePrice ?? this.purchasePrice,
      salePrice: salePrice ?? this.salePrice,
      minStockLevel: minStockLevel ?? this.minStockLevel,
      supplierName: supplierName ?? this.supplierName,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
