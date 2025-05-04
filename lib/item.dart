class Item {
  final int id;
  final String name;
  final int qty;
  final DateTime lastUpdated;
  final String? category;

  Item({
    required this.id,
    required this.name,
    required this.qty,
    required this.lastUpdated,
    this.category,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'qty': qty,
      'last_updated': lastUpdated.millisecondsSinceEpoch,
      'category': category,
    };
  }

  factory Item.fromMap(Map<String, dynamic> map, {int index = 0}) {
    return Item(
      id: map['id'],
      name: map['name'],
      qty: map['qty'],
      lastUpdated: DateTime.tryParse(map['last_updated'] ?? "") ?? DateTime.now(),
      category: map['category'],
    );
  }
}