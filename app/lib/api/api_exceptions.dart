enum ApiError {
  invalidInput,
  upstreamTimeout,
  upstreamError,
  rateLimited,
  internal,
  networkError,
}

class ApiException implements Exception {
  final ApiError code;
  final String message;
  final int? retryAfterSeconds;

  const ApiException({required this.code, this.message = '', this.retryAfterSeconds});

  @override
  String toString() => 'ApiException($code): $message';
}
