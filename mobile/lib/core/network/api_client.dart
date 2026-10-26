//configured HTTP client(e.g, Dio or http)
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class ApiException implements Exception {
  final String message;
  final int? statusCode;

  ApiException(this.message, [this.statusCode]);

  @override
  String toString() => message;
}

class ApiClient {
  final String baseUrl;
  final http.Client _client;

  ApiClient({required this.baseUrl, http.Client? client})
      : _client = client ?? http.Client();

  /// Performs a POST request to the backend
  Future<Map<String, dynamic>> post(String endpoint, Map<String, dynamic> body) async {
    try {
      final uri = Uri.parse('$baseUrl$endpoint');

      final response = await _client.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      // Parse JSON response safely
      final responseData = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return responseData;
      } else {
        // Extract server error message or provide a fallback generic message
        final errorMessage = responseData['message'] ?? 'Authentication failed. Please check your credentials.';
        throw ApiException(errorMessage, response.statusCode);
      }
    } on SocketException {
      throw ApiException('No internet connection. Please check your network settings.');
    } on FormatException {
      throw ApiException('Received invalid response format from the server.');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('An unexpected error occurred. Please try again.');
    }
  }
}