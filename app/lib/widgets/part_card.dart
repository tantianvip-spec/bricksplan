import 'package:flutter/material.dart';
import '../models/inventory_part.dart';

class PartCard extends StatelessWidget {
  final InventoryPart part;
  final bool editable;
  final VoidCallback? onIncrement;
  final VoidCallback? onDecrement;
  final VoidCallback? onDelete;
  final VoidCallback? onConfirm;

  const PartCard({
    super.key,
    required this.part,
    this.editable = false,
    this.onIncrement,
    this.onDecrement,
    this.onDelete,
    this.onConfirm,
  });

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
              if (isLowConfidence && !editable)
                const Positioned(top: -4, right: -4, child: Text('⚠️', style: TextStyle(fontSize: 14))),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(part.partNum, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                Row(
                  children: [
                    Text(
                      part.colorName ?? (isUnknownColor ? '未知颜色' : ''),
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    if (isLowConfidence && editable && onConfirm != null) ...[
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: onConfirm,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.green[100],
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text('确认', style: TextStyle(fontSize: 10, color: Colors.green[800])),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (editable) ...[
            _RoundButton(Icons.remove, onDecrement),
            const SizedBox(width: 8),
            Text('${part.quantity}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(width: 8),
            _RoundButton(Icons.add, onIncrement),
            const SizedBox(width: 4),
            if (onDelete != null)
              GestureDetector(
                onTap: onDelete,
                child: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
              ),
          ] else
            Text('×${part.quantity}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  const _RoundButton(this.icon, this.onTap);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28, height: 28,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(icon, size: 16),
      ),
    );
  }
}
