import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/recognize_response.dart';
import 'api_exceptions.dart';

class ApiClient {
  final String baseUrl;
  final http.Client _client;

  ApiClient({this.baseUrl = 'http://localhost:8000', http.Client? client})
      : _client = client ?? http.Client();

  Future<RecognizeResponse> recognize({required String imagePath}) async {
    final file = File(imagePath);
    if (!file.existsSync()) {
      throw const ApiException(code: ApiError.invalidInput, message: 'File not found');
    }

    try {
      final request = http.MultipartRequest('POST', Uri.parse('$baseUrl/v1/recognize'));
      request.files.add(await http.MultipartFile.fromPath('image', imagePath));

      final streamed = await _client.send(request);
      final response = await http.Response.fromStream(streamed);

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        return RecognizeResponse.fromJson(json);
      }

      final code = _mapError(response.statusCode);
      throw ApiException(code: code, message: response.body);
    } on SocketException {
      throw const ApiException(code: ApiError.networkError, message: 'No network connection');
    } on http.ClientException {
      throw const ApiException(code: ApiError.networkError, message: 'Connection failed');
    }
  }

  static ApiError _mapError(int statusCode) {
    switch (statusCode) {
      case 400: return ApiError.invalidInput;
      case 429: return ApiError.rateLimited;
      case 502: return ApiError.upstreamError;
      case 504: return ApiError.upstreamTimeout;
      default: return ApiError.internal;
    }
  }

  void dispose() {
    _client.close();
  }
}
