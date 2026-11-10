import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'api_config.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;

  const ApiException(this.message, [this.statusCode]);

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient({this.baseUrl, http.Client? client})
    : _client = client ?? http.Client();

  static final instance = ApiClient();

  final String? baseUrl;
  final http.Client _client;

  String get _effectiveBaseUrl => baseUrl ?? ApiConfig.baseUrl;
  String get effectiveBaseUrl => _effectiveBaseUrl;

  Future<String?> Function()? tokenProvider;
  Future<String?> Function()? tokenRefresher;
  Future<void> Function()? onUnauthorized;
  static const _requestTimeout = Duration(seconds: 15);

  Future<dynamic> get(String endpoint, {String? token}) =>
      _send('GET', endpoint, null, authenticated: true, suppliedToken: token);

  Future<Uint8List> getBytes(
    String endpoint, {
    bool authenticated = true,
  }) async {
    final token = authenticated ? await tokenProvider?.call() : null;
    var response = await _request('GET', endpoint, null, token);
    if (response.statusCode == 401 && authenticated) {
      final refreshedToken = await _refreshToken();
      if (refreshedToken != null) {
        response = await _request('GET', endpoint, null, refreshedToken);
      }
    }
    if (response.statusCode == 401 && authenticated) {
      await onUnauthorized?.call();
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      _decodeResponse(response);
    }
    return response.bodyBytes;
  }

  Future<dynamic> post(
    String endpoint,
    Map<String, dynamic>? body, {
    String? token,
    Map<String, String> headers = const {},
  }) => _send(
    'POST',
    endpoint,
    body,
    authenticated: true,
    suppliedToken: token,
    extraHeaders: headers,
  );

  Future<dynamic> postUnauthenticated(
    String endpoint, [
    Map<String, dynamic>? body,
  ]) => _send('POST', endpoint, body, authenticated: false);

  Future<dynamic> postWithoutRefresh(
    String endpoint, [
    Map<String, dynamic>? body,
  ]) => _send(
    'POST',
    endpoint,
    body,
    authenticated: false,
    allowTokenRefresh: false,
  );

  Future<dynamic> put(String endpoint, [Map<String, dynamic>? body]) =>
      _send('PUT', endpoint, body, authenticated: true);

  Future<dynamic> delete(String endpoint) =>
      _send('DELETE', endpoint, null, authenticated: true);

  Future<dynamic> _send(
    String method,
    String endpoint,
    Map<String, dynamic>? body, {
    required bool authenticated,
    bool allowTokenRefresh = true,
    String? suppliedToken,
    Map<String, String> extraHeaders = const {},
  }) async {
    final token = authenticated
        ? suppliedToken ?? await tokenProvider?.call()
        : null;
    var response = await _request(
      method,
      endpoint,
      body,
      token,
      extraHeaders: extraHeaders,
    );

    if (response.statusCode == 401 && authenticated && allowTokenRefresh) {
      final refreshedToken = await _refreshToken();
      if (refreshedToken != null) {
        response = await _request(
          method,
          endpoint,
          body,
          refreshedToken,
          extraHeaders: extraHeaders,
        );
      }
    }

    if (response.statusCode == 401 && authenticated) {
      await onUnauthorized?.call();
    }
    return _decodeResponse(response);
  }

  Future<String?> _refreshToken() async {
    final refresh = tokenRefresher;
    if (refresh == null) return null;

    try {
      return await refresh();
    } on ApiException catch (error) {
      if (error.statusCode == 401 || error.statusCode == 403) {
        return null;
      }
      rethrow;
    }
  }

  Future<http.Response> _request(
    String method,
    String endpoint,
    Map<String, dynamic>? body,
    String? token, {
    Map<String, String> extraHeaders = const {},
  }) async {
    final normalizedBase = _effectiveBaseUrl.replaceFirst(RegExp(r'/+$'), '');
    final normalizedPath = endpoint.startsWith('/') ? endpoint : '/$endpoint';
    final uri = Uri.tryParse('$normalizedBase$normalizedPath');
    if (uri == null ||
        !uri.hasAuthority ||
        uri.host.isEmpty ||
        (uri.scheme != 'http' && uri.scheme != 'https')) {
      throw const ApiException('The server URL is invalid.');
    }

    final request = http.Request(method, uri)
      ..headers['Content-Type'] = 'application/json'
      ..headers['Accept'] = 'application/json'
      ..headers.addAll(extraHeaders);
    if (token != null && token.isNotEmpty) {
      request.headers['Authorization'] = 'Bearer $token';
    }
    if (body != null) request.body = jsonEncode(body);

    try {
      final streamed = await _client.send(request).timeout(_requestTimeout);
      return await http.Response.fromStream(streamed).timeout(_requestTimeout);
    } on SocketException {
      throw const ApiException(
        'Could not connect to the server. Check your connection and server URL, then retry.',
      );
    } on TimeoutException {
      throw const ApiException(
        'The server is taking too long to respond. Please retry.',
      );
    } on HttpException {
      throw const ApiException(
        'Could not connect to the server. Check your connection and server URL, then retry.',
      );
    } on HandshakeException {
      throw const ApiException(
        'Could not establish a secure connection to the server. Check the server URL and certificate.',
      );
    } on http.ClientException {
      throw const ApiException(
        'Could not connect to the server. Check your connection and server URL, then retry.',
      );
    }
  }

  dynamic _decodeResponse(http.Response response) {
    dynamic responseData;
    if (response.body.isNotEmpty) {
      try {
        responseData = jsonDecode(response.body);
      } on FormatException {
        if (response.statusCode < 200 || response.statusCode >= 300) {
          throw ApiException(
            _messageForStatusCode(response.statusCode),
            response.statusCode,
          );
        }
        throw ApiException(
          'The server returned an invalid response.',
          response.statusCode,
        );
      }
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return responseData;
    }

    final serverMessage = responseData is Map
        ? responseData['message'] ?? responseData['error']
        : null;
    final message = serverMessage is String && serverMessage.trim().isNotEmpty
        ? serverMessage
        : _messageForStatusCode(response.statusCode);
    throw ApiException(message, response.statusCode);
  }

  String _messageForStatusCode(int statusCode) => switch (statusCode) {
    404 => 'The API endpoint was not found (404). Check the backend route and server URL.',
    502 || 503 || 504 => 'The server is currently unavailable. Please retry.',
    _ => 'Request failed ($statusCode).',
  };
}
