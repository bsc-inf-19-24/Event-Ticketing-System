import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/core/api_client.dart';
import 'package:mobile/features/interests/data/interest_repository.dart';
import 'package:mobile/features/interests/models/interest.dart';
import 'package:mobile/features/favorites/data/event_favorites_repository.dart';
import 'package:mobile/models/event.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('customer interest API uses catalog and customer endpoints', () async {
    final requests = <http.Request>[];
    final client = ApiClient(
      baseUrl: 'https://tickets.example',
      client: MockClient((request) async {
        requests.add(request);
        if (request.url.path == '/api/interests') {
          return http.Response(
            jsonEncode([
              {'id': 1, 'name': 'Music'},
              {'id': 2, 'name': 'Sports'},
            ]),
            200,
          );
        }
        if (request.url.path == '/api/customers/me/interests' &&
            request.method == 'GET') {
          return http.Response(
            jsonEncode([
              {
                'id': 14,
                'customerId': 57,
                'interest': {'id': 1, 'name': 'Music'},
              },
            ]),
            200,
          );
        }
        if (request.url.path == '/api/customers/me/interests' &&
            request.method == 'POST') {
          return http.Response(
            jsonEncode({
              'id': 15,
              'customerId': 57,
              'interest': {'id': 2, 'name': 'Sports'},
            }),
            200,
          );
        }
        if (request.url.path == '/api/customers/me/interests/1' &&
            request.method == 'DELETE') {
          return http.Response('', 200);
        }
        return http.Response('{"message":"Not found"}', 404);
      }),
    )..tokenProvider = () async => 'customer-token';

    final repository = InterestRepository(apiClient: client);

    final catalog = await repository.fetchCatalog();
    final selections = await repository.fetchMyInterests();
    final added = await repository.addInterest(2);
    await repository.removeInterest(1);

    expect(catalog.map((value) => value.name), ['Music', 'Sports']);
    expect(selections.single.interest.id, 1);
    expect(added.interest.id, 2);
    expect(
      requests
          .where((request) => request.url.path == '/api/customers/me/interests')
          .any((request) => request.method == 'GET'),
      isTrue,
    );
    expect(
      requests
          .where(
            (request) => request.url.path == '/api/customers/me/interests/1',
          )
          .single
          .method,
      'DELETE',
    );
    expect(
      requests
          .where((request) => request.url.path == '/api/customers/me/interests')
          .where((request) => request.method == 'POST')
          .single
          .url
          .queryParameters['interestId'],
      '2',
    );
  });

  test('interest model tolerates schema-sensitive optional IDs', () {
    final interest = Interest.fromJson({'id': '7', 'name': 'Art'});
    final customerInterest = CustomerInterest.fromJson({
      'customerId': '57',
      'interest': {'id': 7, 'name': 'Art'},
    });

    expect(interest.id, 7);
    expect(customerInterest.id, isNull);
    expect(customerInterest.customerId, 57);
    expect(customerInterest.interest.name, 'Art');
  });

  test('For You ranking moves Sports events ahead', () async {
    final client = ApiClient(
      baseUrl: 'https://tickets.example',
      client: MockClient((request) async {
        if (request.url.path == '/api/customers/me/interests') {
          return http.Response(
            jsonEncode([
              {
                'id': 14,
                'customerId': 57,
                'interest': {'id': 2, 'name': 'Sports'},
              },
            ]),
            200,
          );
        }
        return http.Response('{"message":"Not found"}', 404);
      }),
    )..tokenProvider = () async => 'customer-token';
    final repository = InterestRepository(apiClient: client);
    final music = const Event(
      id: 'music-1',
      title: 'Concert',
      date: '',
      time: '',
      venue: '',
      price: 100,
      imagePath: '',
      category: 'Concerts',
    );
    final sports = const Event(
      id: 'sports-1',
      title: 'Cup Final',
      date: '',
      time: '',
      venue: '',
      price: 100,
      imagePath: '',
      category: 'Sports',
    );

    final ranked = await repository.personalizeEvents([music, sports]);

    expect(ranked.first.category, 'Sports');
  });

  test('event favorites are toggled and account-scoped', () async {
    final repository = EventFavoritesRepository();

    expect(await repository.isFavorite('event-1'), isFalse);
    expect(await repository.toggleFavorite('event-1'), isTrue);
    expect(await repository.isFavorite('event-1'), isTrue);
    expect(await repository.toggleFavorite('event-1'), isFalse);
    expect(await repository.isFavorite('event-1'), isFalse);
  });
}
