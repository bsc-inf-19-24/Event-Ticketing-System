//configured HTTP client(e.g, Dio or http)
import 'dart:async';
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

  Future<dynamic> get(String endpoint, {String? token}) async {
    final normalizedBase = baseUrl.replaceFirst(RegExp(r'/+$'), '');
    final normalizedPath = endpoint.startsWith('/') ? endpoint : '/$endpoint';
    final uri = Uri.tryParse('$normalizedBase$normalizedPath');
    if (uri == null ||
        !uri.hasAuthority ||
        uri.host.isEmpty ||
        (uri.scheme != 'http' && uri.scheme != 'https')) {
      throw ApiException('The server URL is invalid.');
    }

    try {
      final response = await _client
          .get(
            uri,
            headers: {
              'Accept': 'application/json',
              if (token != null && token.isNotEmpty)
                'Authorization': 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: 15));
      dynamic decoded;
      if (response.body.isNotEmpty) {
        try {
          decoded = jsonDecode(response.body);
        } on FormatException {
          throw ApiException(
            'Received invalid response format from the server.',
            response.statusCode,
          );
        }
      }

      if (response.statusCode < 200 || response.statusCode >= 300) {
        final body = decoded is Map ? decoded : const {};
        final message = body['message'] ?? body['error'];
        throw ApiException(
          message is String && message.trim().isNotEmpty
              ? message
              : 'Request failed (${response.statusCode}).',
          response.statusCode,
        );
      }
      return decoded;
    } on SocketException {
      throw ApiException(
        'Could not reach the server at $baseUrl. Check your connection and server address.',
      );
    } on TimeoutException {
      throw ApiException('The server took too long to respond.');
    } on HttpException {
      throw ApiException('Could not read the server response.');
    } on http.ClientException {
      throw ApiException('Could not connect to the server.');
    }
  }

  /// Performs a POST request to the backend.
  Future<Map<String, dynamic>> post(
    String endpoint,
    Map<String, dynamic> body, {
    String? token,
  }) async {
    final normalizedBase = baseUrl.replaceFirst(RegExp(r'/+$'), '');
    final normalizedPath = endpoint.startsWith('/') ? endpoint : '/$endpoint';
    final uri = Uri.tryParse('$normalizedBase$normalizedPath');
    if (uri == null ||
        !uri.hasAuthority ||
        uri.host.isEmpty ||
        (uri.scheme != 'http' && uri.scheme != 'https')) {
      throw ApiException('The server URL is invalid.');
    }

    try {
      final response = await _client
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              if (token != null && token.isNotEmpty)
                'Authorization': 'Bearer $token',
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 15));

      dynamic decoded;
      if (response.body.isNotEmpty) {
        try {
          decoded = jsonDecode(response.body);
        } on FormatException {
          throw ApiException(
            'Received invalid response format from the server.',
            response.statusCode,
          );
        }
      }

      if (response.statusCode < 200 || response.statusCode >= 300) {
        final payload = decoded is Map ? decoded : const {};
        final errorMessage =
            payload['message'] ?? payload['error'] ??
            'Request failed (${response.statusCode}).';
        throw ApiException(
          errorMessage is String && errorMessage.trim().isNotEmpty
              ? errorMessage
              : 'Request failed (${response.statusCode}).',
          response.statusCode,
        );
      }

      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
      return const {};
    } on SocketException {
      throw ApiException(
        'Could not reach the server at $baseUrl. Check the server address, port, '
        'network, and firewall.',
      );
    } on TimeoutException {
      throw ApiException('The server took too long to respond.');
    } on HttpException {
      throw ApiException('Could not read the server response.');
    } on http.ClientException {
      throw ApiException('Could not connect to the server.');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('An unexpected error occurred. Please try again.');
    }
  }
}
export '../api_client.dart';
