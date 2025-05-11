class Category {
  final int? id;  // Make nullable for new categories
  final String name;
  final String description;
  final String icon;
  final bool isExpense;

  // Getter for type (expense or income)
  String get type => isExpense ? 'expense' : 'income';

  Category({
    this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.isExpense,
  });

  factory Category.fromMap(Map<String, dynamic> map) {
    return Category(
      id: map['id'] as int?,
      name: map['name'] as String,
      description: map['description'] as String? ?? '',
      icon: map['icon'] as String,
      isExpense: (map['isExpense'] as int) == 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'description': description,
      'icon': icon,
      'isExpense': isExpense ? 1 : 0,
    };
  }

  Category copyWith({
    int? id,
    String? name,
    String? description,
    String? icon,
    bool? isExpense,
  }) {
    return Category(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      icon: icon ?? this.icon,
      isExpense: isExpense ?? this.isExpense,
    );
  }
}