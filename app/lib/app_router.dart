import 'package:go_router/go_router.dart';
import 'pages/home/home_page.dart';
import 'pages/capture/capture_page.dart';
import 'pages/confirm/confirm_page.dart';
import 'pages/loading/loading_page.dart';
import 'pages/result/result_page.dart';
import 'pages/add_part/add_part_page.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', builder: (context, state) => const HomePage()),
    GoRoute(path: '/capture', builder: (context, state) => const CapturePage()),
    GoRoute(
      path: '/confirm',
      builder: (context, state) {
        final extra = state.extra;
        if (extra is String) {
          return ConfirmPage(imagePath: extra);
        }
        final map = extra as Map<String, dynamic>;
        return ConfirmPage(
          imagePath: map['imagePath'] as String,
          sessionId: map['retakeSessionId'] as String?,
        );
      },
    ),
    GoRoute(
      path: '/loading',
      builder: (context, state) {
        final extra = state.extra;
        if (extra is String) {
          return LoadingPage(imagePath: extra);
        }
        final map = extra as Map<String, dynamic>;
        return LoadingPage(
          imagePath: map['imagePath'] as String,
          sessionId: map['sessionId'] as String?,
        );
      },
    ),
    GoRoute(
      path: '/result/:sessionId',
      builder: (context, state) {
        final sessionId = state.pathParameters['sessionId']!;
        return ResultPage(sessionId: sessionId);
      },
    ),
    GoRoute(
      path: '/add-part/:sessionId',
      builder: (context, state) {
        final sessionId = state.pathParameters['sessionId']!;
        return AddPartPage(sessionId: sessionId);
      },
    ),
  ],
);
