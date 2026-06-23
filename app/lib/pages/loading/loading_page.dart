import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../api/api_client.dart';
import '../../api/api_exceptions.dart';
import '../../repository/local_repository.dart';
import '../../models/inventory_session.dart';
import '../../models/inventory_part.dart';

class LoadingPage extends StatefulWidget {
  final String imagePath;
  const LoadingPage({super.key, required this.imagePath});

  @override
  State<LoadingPage> createState() => _LoadingPageState();
}

class _LoadingPageState extends State<LoadingPage> {
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    try {
      final api = context.read<ApiClient>();
      final repo = context.read<LocalRepository>();

      final response = await api.recognize(imagePath: widget.imagePath);

      final sessionId = const Uuid().v4();
      final now = DateTime.now();
      final session = InventorySession(
        id: sessionId,
        name: '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} 识别',
        createdAt: now,
        updatedAt: now,
        partCount: response.parts.length,
      );
      await repo.insertSession(session);

      for (final item in response.parts) {
        await repo.insertPart(InventoryPart(
          sessionId: sessionId,
          partNum: item.partNum,
          colorId: item.colorId,
          quantity: item.quantity,
          confidence: item.confidence,
          source: 'recognized',
        ));
      }

      if (mounted) context.go('/result/$sessionId');
    } on ApiException catch (e) {
      setState(() { _errorMessage = _errorLabel(e.code); });
    } catch (_) {
      setState(() { _errorMessage = '识别失败，请重试'; });
    }
  }

  String _errorLabel(ApiError code) {
    switch (code) {
      case ApiError.invalidInput: return '图片有问题，请重选';
      case ApiError.upstreamTimeout: return '网络慢，再试一次';
      case ApiError.upstreamError: return '识别服务暂时不可用';
      case ApiError.rateLimited: return '今天用得有点多，过会儿再来';
      case ApiError.networkError: return '网络连接失败，请检查网络';
      case ApiError.internal: return '出错了，已记录';
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(title: const Text('识别中')),
        body: Center(
          child: _errorMessage != null
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, size: 64, color: Colors.red),
                    const SizedBox(height: 16),
                    Text(_errorMessage!, style: const TextStyle(fontSize: 16)),
                    const SizedBox(height: 24),
                    ElevatedButton(onPressed: () => context.pop(), child: const Text('返回重试')),
                  ],
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const _AnimatedBrick(),
                    const SizedBox(height: 24),
                    const Text('正在识别砖块…', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text('大约需要 5-15 秒', style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                    const SizedBox(height: 40),
                    TextButton(onPressed: () => context.pop(), child: const Text('取消')),
                  ],
                ),
        ),
      ),
    );
  }
}

class _AnimatedBrick extends StatefulWidget {
  @override
  State<_AnimatedBrick> createState() => _AnimatedBrickState();
}

class _AnimatedBrickState extends State<_AnimatedBrick> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: Tween<double>(begin: 0.9, end: 1.1).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeInOut)),
      child: const Text('🧱', style: TextStyle(fontSize: 64)),
    );
  }
}
