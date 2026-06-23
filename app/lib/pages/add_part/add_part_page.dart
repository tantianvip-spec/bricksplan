import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../theme/app_theme.dart';
import '../../repository/local_repository.dart';
import '../../models/inventory_part.dart';

class AddPartPage extends StatefulWidget {
  final String sessionId;
  const AddPartPage({super.key, required this.sessionId});

  @override
  State<AddPartPage> createState() => _AddPartPageState();
}

class _AddPartPageState extends State<AddPartPage> {
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _results = [];
  bool _searching = false;
  int _quantity = 1;
  int _selectedColorId = 4;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    if (query.trim().isEmpty) return;
    setState(() { _searching = true; });

    try {
      final resp = await http.get(
        Uri.parse('http://121.37.166.59:8000/v1/parts/search?q=${Uri.encodeQueryComponent(query)}'),
      );
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        setState(() { _results = (data['results'] as List).cast<Map<String, dynamic>>(); });
      }
    } catch (_) {
      // ignore search errors
    }
    setState(() { _searching = false; });
  }

  Future<void> _addPart(Map<String, dynamic> item) async {
    final repo = context.read<LocalRepository>();
    await repo.insertPart(InventoryPart(
      sessionId: widget.sessionId,
      partNum: item['part_num'] as String,
      colorId: _selectedColorId,
      quantity: _quantity,
      source: 'manual',
      colorName: '',
    ));
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('添加零件')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '搜索件号，如 3001',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searching
                    ? const SizedBox(width: 24, height: 24, child: Center(child: CircularProgressIndicator(strokeWidth: 2)))
                    : IconButton(
                        icon: const Icon(Icons.search),
                        onPressed: () => _search(_searchController.text),
                      ),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onSubmitted: _search,
            ),
          ),
          if (_results.isEmpty && !_searching)
            const Expanded(
              child: Center(child: Text('输入件号搜索', style: TextStyle(color: Colors.grey))),
            )
          else
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _results.length,
                itemBuilder: (context, index) {
                  final item = _results[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: Container(
                        width: 44, height: 44,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.grid_view_rounded, color: Colors.grey),
                      ),
                      title: Text(item['part_num'] as String, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(item['name'] as String? ?? ''),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _QtySelector(
                            value: _quantity,
                            onChanged: (v) => setState(() { _quantity = v; }),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: () => _addPart(item),
                            child: const Text('添加'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.legoYellow,
                              foregroundColor: AppTheme.darkText,
                            ),
                          ),
                        ],
                      ),
                      onTap: () => _addPart(item),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _QtySelector extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;

  const _QtySelector({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: value > 1 ? () => onChanged(value - 1) : null,
          child: Container(
            width: 28, height: 28,
            decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(14)),
            child: const Icon(Icons.remove, size: 16),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text('$value', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ),
        GestureDetector(
          onTap: value < 99 ? () => onChanged(value + 1) : null,
          child: Container(
            width: 28, height: 28,
            decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(14)),
            child: const Icon(Icons.add, size: 16),
          ),
        ),
      ],
    );
  }
}
