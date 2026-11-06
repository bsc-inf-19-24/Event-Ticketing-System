import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/core/api_client.dart';
import 'package:mobile/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:mobile/features/profile/data/profile_repository.dart';

void main() {
  test(
    'registration sends the role and parses the returned token pair',
    () async {
      late http.Request request;
      final client = ApiClient(
        baseUrl: 'https://tickets.example',
        client: MockClient((incoming) async {
          request = incoming;
          return http.Response(
            jsonEncode({
              'token': 'access-token',
              'refreshToken': 'refresh-token',
              'user': {
                'id': 42,
                'name': 'Alex Customer',
                'email': 'alex@example.com',
              },
            }),
            201,
          );
        }),
      );
      final auth = ApiAuthService(apiClient: client);

      final user = await auth.register(
        name: 'Alex Customer',
        email: 'alex@example.com',
        password: 'pass12345',
        role: 'CUSTOMER',
      );

      expect(request.method, 'POST');
      expect(request.url.path, '/api/auth/register');
      expect(jsonDecode(request.body)['role'], 'CUSTOMER');
      expect(user.id, '42');
      expect(user.token, 'access-token');
      expect(user.refreshToken, 'refresh-token');
    },
  );

  test('profile requests use the customer profile GET endpoint', () async {
    late http.Request request;
    final client = ApiClient(
      baseUrl: 'https://tickets.example',
      client: MockClient((incoming) async {
        request = incoming;
        return http.Response(
          jsonEncode({
            'id': 'customer-1',
            'name': 'Alex Customer',
            'email': 'alex@example.com',
          }),
          200,
        );
      }),
    )..tokenProvider = () async => 'profile-token';
    final auth = ApiAuthService(apiClient: client);

    final profile = await auth.getCurrentProfile();

    expect(request.method, 'GET');
    expect(request.url.path, '/api/customers/me');
    expect(request.headers['Authorization'], 'Bearer profile-token');
    expect(profile.email, 'alex@example.com');
  });

  test('profile updates use PUT on the customer profile endpoint', () async {
    late http.Request request;
    final repository = ProfileRepository(
      apiClient: ApiClient(
        baseUrl: 'https://tickets.example',
        client: MockClient((incoming) async {
          request = incoming;
          return http.Response(
            '{"name":"Alex Updated","email":"alex@example.com"}',
            200,
          );
        }),
      ),
    );

    final profile = await repository.updateUserProfile({
      'name': 'Alex Updated',
    });

    expect(request.method, 'PUT');
    expect(request.url.path, '/api/customers/me');
    expect(jsonDecode(request.body), {'name': 'Alex Updated'});
    expect(profile['name'], 'Alex Updated');
  });

  test(
    'retries an authenticated request once with a refreshed token',
    () async {
      final authorizationHeaders = <String?>[];
      var requestCount = 0;
      var unauthorizedCalled = false;
      final client = ApiClient(
        baseUrl: 'https://tickets.example',
        client: MockClient((request) async {
          authorizationHeaders.add(request.headers['Authorization']);
          requestCount++;
          if (requestCount == 1) {
            return http.Response('{"message":"expired"}', 401);
          }
          return http.Response('{"id":"customer-1"}', 200);
        }),
      );
      client.tokenProvider = () async => 'expired-token';
      client.tokenRefresher = () async => 'fresh-token';
      client.onUnauthorized = () async {
        unauthorizedCalled = true;
      };

      await client.get('/api/customers/me');

      expect(requestCount, 2);
      expect(authorizationHeaders, [
        'Bearer expired-token',
        'Bearer fresh-token',
      ]);
      expect(unauthorizedCalled, isFalse);
    },
  );

  test('Google authentication sends the ID token to its endpoint', () async {
    late http.Request request;
    final client = ApiClient(
      baseUrl: 'https://tickets.example',
      client: MockClient((incoming) async {
        request = incoming;
        return http.Response(
          '{"token":"access","refreshToken":"refresh","email":"a@example.com"}',
          200,
        );
      }),
    );

    await ApiAuthService(apiClient: client).loginWithGoogle('google-id-token');

    expect(request.url.path, '/api/auth/google');
    expect(jsonDecode(request.body), {'idToken': 'google-id-token'});
  });

  test('connection failures are exposed as a friendly API error', () async {
    final client = ApiClient(
      baseUrl: 'https://tickets.example',
      client: MockClient(
        (_) async => throw http.ClientException('connection refused'),
      ),
    );

    await expectLater(
      client.postUnauthenticated('/api/auth/login', {
        'email': 'alex@example.com',
        'password': 'password',
      }),
      throwsA(
        isA<ApiException>().having(
          (error) => error.message,
          'message',
          contains('Could not connect to the server'),
        ),
      ),
    );
  });
}
