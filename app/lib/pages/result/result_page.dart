import 'package:flutter/material.dart';
import '../../widgets/empty_state.dart';
import '../../theme/app_theme.dart';

class ResultPage extends StatefulWidget {
  final String sessionId;
  const ResultPage({super.key, required this.sessionId});

  @override
  State<ResultPage> createState() => _ResultPageState();
}

class _ResultPageState extends State<ResultPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('零件清单')),
      body: const Center(child: Text('加载中…')),
    );
  }
}
