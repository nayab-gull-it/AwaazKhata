/// Represents a customer credit (udhaar) transaction.
///
/// Tracks who owes money, how much, when the debt was recorded,
/// and whether it has been settled.
class UdhaarEntry {
  const UdhaarEntry({
    required this.id,
    required this.customerName,
    required this.phoneNumber,
    required this.amount,
    required this.createdAt,
    this.description,
    this.isPaid = false,
    this.paidAt,
  });

  /// Unique identifier for this credit entry.
  final String id;

  /// Name of the customer who took the item on credit.
  final String customerName;

  /// Contact number used for follow-up reminders.
  final String phoneNumber;

  /// Outstanding or settled amount in Pakistani Rupees.
  final double amount;

  /// Optional note describing what was sold on credit.
  final String? description;

  /// Date and time when the udhaar was recorded.
  final DateTime createdAt;

  /// True if the customer has fully paid back the amount.
  final bool isPaid;

  /// Date and time when the amount was settled, if applicable.
  final DateTime? paidAt;

  /// Creates a copy with selected fields updated, preserving immutability.
  UdhaarEntry copyWith({
    String? id,
    String? customerName,
    String? phoneNumber,
    double? amount,
    String? description,
    DateTime? createdAt,
    bool? isPaid,
    DateTime? paidAt,
  }) {
    return UdhaarEntry(
      id: id ?? this.id,
      customerName: customerName ?? this.customerName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      amount: amount ?? this.amount,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      isPaid: isPaid ?? this.isPaid,
      paidAt: paidAt ?? this.paidAt,
    );
  }

  /// Serializes this entry to JSON for local persistence.
  Map<String, dynamic> toJson() => {
        'id': id,
        'customerName': customerName,
        'phoneNumber': phoneNumber,
        'amount': amount,
        'description': description,
        'createdAt': createdAt.toIso8601String(),
        'isPaid': isPaid,
        'paidAt': paidAt?.toIso8601String(),
      };

  /// Deserializes an entry from JSON stored by [toJson].
  factory UdhaarEntry.fromJson(Map<String, dynamic> json) => UdhaarEntry(
        id: json['id'] as String,
        customerName: json['customerName'] as String,
        phoneNumber: json['phoneNumber'] as String? ?? '',
        amount: (json['amount'] as num).toDouble(),
        description: json['description'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
        isPaid: json['isPaid'] as bool? ?? false,
        paidAt: json['paidAt'] == null
            ? null
            : DateTime.parse(json['paidAt'] as String),
      );
}
