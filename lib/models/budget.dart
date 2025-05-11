class Budget {
  final String? id;
  final String category;
  final double limit;
  final String period; // 'monthly', 'weekly', etc.

  Budget({
    this.id,
    required this.category,
    required this.limit,
    required this.period,
  });

  factory Budget.fromJson(Map<String, dynamic> json) {
    return Budget(
      id: json['id'] as String?,
      category: json['category'] as String,
      limit: json['limit'] as double,
      period: json['period'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'category': category,
      'limit': limit,
      'period': period,
    };
  }
}
