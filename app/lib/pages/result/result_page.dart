import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../repository/local_repository.dart';
import '../../models/inventory_part.dart';
import '../../widgets/part_card.dart';
import '../../widgets/empty_state.dart';
import '../../theme/app_theme.dart';

class ResultPage extends StatefulWidget {
  final String sessionId;
  const ResultPage({super.key, required this.sessionId});

  @override
  State<ResultPage> createState() => _ResultPageState();
}

class _ResultPageState extends State<ResultPage> {
  List<InventoryPart> _parts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repo = context.read<LocalRepository>();
    final parts = await repo.getParts(widget.sessionId);
    setState(() {
      _parts = parts;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('零件清单')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _parts.isEmpty
              ? const EmptyState(icon: Icons.search_off, message: '未识别出零件，试试换个角度或光线')
              : Column(
                  children: [
                    Container(
                      width: double.infinity,
                      color: AppTheme.legoBlue,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Text(
                        '共识别 ${_parts.length} 种零件 · ${_parts.fold(0, (sum, p) => sum + p.quantity)} 件',
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _parts.length,
                        itemBuilder: (context, index) => PartCard(part: _parts[index]),
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
                              onPressed: null,
                              icon: const Icon(Icons.camera_alt),
                              label: const Text('补拍'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: null,
                              icon: const Icon(Icons.edit),
                              label: const Text('编辑'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }
}
