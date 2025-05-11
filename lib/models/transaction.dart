class Transaction {
  final int? id;  // Make nullable for new transactions
  final String description;
  final double amount;
  final DateTime date;
  final String type;
  final String category;
  final String? notes;

  Transaction({
    this.id,
    required this.description,
    required this.amount,
    required this.date,
    required this.type,
    required this.category,
    this.notes,
  });

  factory Transaction.fromMap(Map<String, dynamic> map) {
    return Transaction(
      id: map['id'] as int?,
      description: map['description'] as String,
      amount: map['amount'] as double,
      date: DateTime.parse(map['date'] as String),
      type: map['type'] as String,
      category: map['category'] as String,
      notes: map['notes'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'description': description,
      'amount': amount,
      'date': date.toIso8601String(),
      'type': type.toLowerCase(),
      'category': category,
      if (notes != null) 'notes': notes,
    };
  }

  Transaction copyWith({
    int? id,
    String? description,
    double? amount,
    DateTime? date,
    String? type,
    String? category,
    String? notes,
  }) {
    return Transaction(
      id: id ?? this.id,
      description: description ?? this.description,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      type: type ?? this.type,
      category: category ?? this.category,
      notes: notes ?? this.notes,
    );
  }

  @override
  String toString() {
    return 'Transaction(id: $id, amount: $amount, type: $type, date: $date, description: $description, category: $category, notes: $notes)';
  }
}