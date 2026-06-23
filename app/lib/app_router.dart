import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'pages/home/home_page.dart';
import 'pages/capture/capture_page.dart';
import 'pages/confirm/confirm_page.dart';
import 'pages/loading/loading_page.dart';
import 'pages/result/result_page.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', builder: (context, state) => const HomePage()),
    GoRoute(path: '/capture', builder: (context, state) => const CapturePage()),
    GoRoute(
      path: '/confirm',
      builder: (context, state) {
        final imagePath = state.extra as String;
        return ConfirmPage(imagePath: imagePath);
      },
    ),
    GoRoute(
      path: '/loading',
      builder: (context, state) {
        final imagePath = state.extra as String;
        return LoadingPage(imagePath: imagePath);
      },
    ),
    GoRoute(
      path: '/result/:sessionId',
      builder: (context, state) {
        final sessionId = state.pathParameters['sessionId']!;
        return ResultPage(sessionId: sessionId);
      },
    ),
  ],
);
