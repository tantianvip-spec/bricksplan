import 'package:flutter/material.dart';
import '../models/inventory_part.dart';

class PartCard extends StatelessWidget {
  final InventoryPart part;

  const PartCard({super.key, required this.part});

  Color _colorFromId(int id) {
    switch (id) {
      case 0: return Colors.black;
      case 1: return Colors.blue;
      case 2: return Colors.green;
      case 4: return const Color(0xFFED1C24);
      case 5: return const Color(0xFFE91E63);
      case 7: return Colors.grey;
      case 14: return const Color(0xFFFFD700);
      case 15: return Colors.white;
      case 71: return Colors.blueGrey;
      case 72: return Colors.blueGrey[800]!;
      default: return Colors.grey[300]!;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLowConfidence = (part.confidence ?? 1.0) < 0.6;
    final isUnknownColor = part.colorId == -1;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isLowConfidence ? const Color(0xFFFFF8E1) : Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: isLowConfidence ? Border.all(color: const Color(0xFFFFD700)) : null,
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Stack(
            children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: isUnknownColor ? Colors.grey[300] : _colorFromId(part.colorId),
                  borderRadius: BorderRadius.circular(8),
                  border: part.colorId == 15 ? Border.all(color: Colors.grey[300]!) : null,
                ),
                child: isUnknownColor
                    ? const Center(child: Text('?', style: TextStyle(color: Colors.grey, fontSize: 18)))
                    : null,
              ),
              if (isLowConfidence)
                const Positioned(top: -4, right: -4, child: Text('⚠️', style: TextStyle(fontSize: 14))),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(part.partNum, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                Text(
                  part.colorName ?? (isUnknownColor ? '未知颜色' : ''),
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          Text('×${part.quantity}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
