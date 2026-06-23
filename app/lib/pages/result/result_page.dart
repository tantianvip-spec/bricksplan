import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../repository/local_repository.dart';
import '../../models/inventory_part.dart';
import '../../widgets/part_card.dart';
import '../../widgets/empty_state.dart';
import '../../theme/app_theme.dart';

const List<Color> _colorChips = [
  Color(0xFFED1C24), Colors.blue, Colors.green, Color(0xFFFFD700),
  Colors.white, Colors.black, Colors.grey, Colors.blueGrey,
];

class ResultPage extends StatefulWidget {
  final String sessionId;
  const ResultPage({super.key, required this.sessionId});

  @override
  State<ResultPage> createState() => _ResultPageState();
}

class _ResultPageState extends State<ResultPage> {
  List<InventoryPart> _parts = [];
  bool _loading = true;
  bool _editing = false;
  int? _filterColorId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    if (!mounted) return;
    final repo = context.read<LocalRepository>();
    final parts = await repo.getParts(widget.sessionId);
    if (!mounted) return;
    setState(() { _parts = parts; _loading = false; });
  }

  List<InventoryPart> get _filteredParts {
    if (_filterColorId == null) return _parts;
    return _parts.where((p) => p.colorId == _filterColorId).toList();
  }

  Future<void> _updateQuantity(InventoryPart part, int delta) async {
    final repo = context.read<LocalRepository>();
    final newQty = part.quantity + delta;
    if (newQty <= 0) {
      await repo.deletePart(widget.sessionId, part.partNum, part.colorId);
      setState(() { _parts.removeWhere((p) => p.partNum == part.partNum && p.colorId == part.colorId); });
    } else {
      final updated = part.copyWith(quantity: newQty);
      await repo.updatePart(updated);
      setState(() {
        final idx = _parts.indexWhere((p) => p.partNum == part.partNum && p.colorId == part.colorId);
        if (idx >= 0) _parts[idx] = updated;
      });
    }
  }

  Future<void> _deletePart(InventoryPart part) async {
    final repo = context.read<LocalRepository>();
    await repo.deletePart(widget.sessionId, part.partNum, part.colorId);
    setState(() { _parts.removeWhere((p) => p.partNum == part.partNum && p.colorId == part.colorId); });
  }

  Future<void> _confirmPart(InventoryPart part) async {
    final repo = context.read<LocalRepository>();
    final updated = part.copyWith(source: 'edited');
    await repo.updatePart(updated);
    setState(() {
      final idx = _parts.indexWhere((p) => p.partNum == part.partNum && p.colorId == part.colorId);
      if (idx >= 0) _parts[idx] = updated;
    });
  }

  @override
  Widget build(BuildContext context) {
    final total = _parts.fold(0, (sum, p) => sum + p.quantity);

    return Scaffold(
      appBar: AppBar(
        title: const Text('零件清单'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => context.push('/add-part/${widget.sessionId}'),
            tooltip: '添加零件',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _parts.isEmpty
              ? const EmptyState(icon: Icons.search_off, message: '未识别出零件')
              : Column(
                  children: [
                    Container(
                      width: double.infinity,
                      color: AppTheme.legoBlue,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Text(
                        '共识别 ${_parts.length} 种零件 · $total 件',
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                      ),
                    ),
                    // Color filter chips
                    SizedBox(
                      height: 48,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        children: [
                          _filterChip(null, '全部'),
                          ..._colorChips.map((c) => _filterChip(c)),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _filteredParts.length,
                        itemBuilder: (context, index) {
                          final part = _filteredParts[index];
                          return PartCard(
                            part: part,
                            editable: _editing,
                            onIncrement: _editing ? () => _updateQuantity(part, 1) : null,
                            onDecrement: _editing ? () => _updateQuantity(part, -1) : null,
                            onDelete: _editing ? () => _deletePart(part) : null,
                            onConfirm: _editing ? () => _confirmPart(part) : null,
                          );
                        },
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: const BoxDecoration(
                        border: Border(top: BorderSide(color: Color(0xFFEEEEEE))),
                        color: Colors.white,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => context.push('/capture', extra: widget.sessionId),
                              icon: const Icon(Icons.camera_alt),
                              label: const Text('补拍'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => setState(() { _editing = !_editing; }),
                              icon: Icon(_editing ? Icons.check : Icons.edit),
                              label: Text(_editing ? '完成' : '编辑'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _editing ? AppTheme.legoBlue : null,
                                foregroundColor: _editing ? Colors.white : null,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _filterChip(Color? color, [String? label]) {
    final selected = _filterColorId == null && color == null
        || color != null && _filterColorId == _parts.firstWhere((p) => p.colorId == _findColorId(color),
            orElse: () => _parts.first).colorId;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: label != null ? Text(label, style: const TextStyle(fontSize: 12)) : const SizedBox(width: 20, height: 20),
        selected: selected,
        onSelected: (_) => setState(() { _filterColorId = color == null ? null : _findColorId(color); }),
      ),
    );
  }

  int _findColorId(Color color) {
    if (color == const Color(0xFFED1C24)) return 4;
    if (color == Colors.blue) return 1;
    if (color == Colors.green) return 2;
    if (color == const Color(0xFFFFD700)) return 14;
    if (color == Colors.white) return 15;
    if (color == Colors.black) return 0;
    if (color == Colors.grey) return 7;
    if (color == Colors.blueGrey) return 71;
    return -1;
  }
}
