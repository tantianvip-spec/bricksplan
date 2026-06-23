class InventoryPart {
  final String sessionId;
  final String partNum;
  final int colorId;
  final int quantity;
  final String source;
  final double? confidence;
  final String? colorName;

  const InventoryPart({
    required this.sessionId,
    required this.partNum,
    required this.colorId,
    this.quantity = 1,
    this.source = 'recognized',
    this.confidence,
    this.colorName,
  });

  InventoryPart copyWith({int? quantity, String? source}) => InventoryPart(
    sessionId: sessionId,
    partNum: partNum,
    colorId: colorId,
    quantity: quantity ?? this.quantity,
    source: source ?? this.source,
    confidence: confidence,
    colorName: colorName,
  );

  Map<String, dynamic> toMap() => {
    'session_id': sessionId,
    'part_num': partNum,
    'color_id': colorId,
    'quantity': quantity,
    'source': source,
    'confidence': confidence,
    'color_name': colorName,
  };

  factory InventoryPart.fromMap(Map<String, dynamic> map) => InventoryPart(
    sessionId: map['session_id'] as String,
    partNum: map['part_num'] as String,
    colorId: map['color_id'] as int,
    quantity: map['quantity'] as int? ?? 1,
    source: map['source'] as String? ?? 'recognized',
    confidence: (map['confidence'] as num?)?.toDouble(),
    colorName: map['color_name'] as String?,
  );

  @override
  bool operator ==(Object other) =>
    other is InventoryPart && other.partNum == partNum && other.colorId == colorId;

  @override
  int get hashCode => Object.hash(partNum, colorId);
}
