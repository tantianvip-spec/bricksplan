class PartItem {
  final String partNum;
  final int colorId;
  final int quantity;
  final double? confidence;

  const PartItem({
    required this.partNum,
    required this.colorId,
    this.quantity = 1,
    this.confidence,
  });

  factory PartItem.fromJson(Map<String, dynamic> json) => PartItem(
    partNum: json['part_num'] as String,
    colorId: json['color_id'] as int,
    quantity: json['quantity'] as int? ?? 1,
    confidence: (json['confidence'] as num?)?.toDouble(),
  );
}

class RecognizeResponse {
  final List<PartItem> parts;
  final bool cacheHit;
  final int lowConfidenceCount;

  const RecognizeResponse({
    required this.parts,
    required this.cacheHit,
    required this.lowConfidenceCount,
  });

  factory RecognizeResponse.fromJson(Map<String, dynamic> json) => RecognizeResponse(
    parts: (json['parts'] as List).map((e) => PartItem.fromJson(e as Map<String, dynamic>)).toList(),
    cacheHit: json['cache_hit'] as bool? ?? false,
    lowConfidenceCount: json['low_confidence_count'] as int? ?? 0,
  );
}
