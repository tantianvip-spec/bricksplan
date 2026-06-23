class InventorySession {
  final String id;
  final String name;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int partCount;
  final String? thumbnail;

  const InventorySession({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    this.partCount = 0,
    this.thumbnail,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'created_at': createdAt.millisecondsSinceEpoch,
    'updated_at': updatedAt.millisecondsSinceEpoch,
    'part_count': partCount,
    'thumbnail': thumbnail,
  };

  factory InventorySession.fromMap(Map<String, dynamic> map) => InventorySession(
    id: map['id'] as String,
    name: map['name'] as String? ?? '',
    createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int),
    partCount: map['part_count'] as int? ?? 0,
    thumbnail: map['thumbnail'] as String?,
  );
}
