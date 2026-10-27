import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/auth/logic/auth_controller.dart';
import 'package:mobile/features/auth/models/app_user.dart';
import 'package:mobile/features/auth/services/auth_service.dart';
import 'package:mobile/features/auth/services/fake_auth_service.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/features/auth/data/datasources/mock_auth_remote_datasource.dart';

void main() {
  late FakeAuthService service;

  setUp(() {
    service = FakeAuthService();
  });

  group('FakeAuthService', () {
    test(
      'accepts each documented demo account through the app data source',
      () async {
        final dataSource = MockAuthRemoteDataSource(authService: service);
        final credentials = {
          'demo@ticketmaster.mw': 'demo1234',
          'test.customer@example.com': 'SecurePassword123!',
          'admin@example.com': 'password123',
        };

        for (final entry in credentials.entries) {
          final user = await dataSource.login(entry.key, entry.value);
          expect(user.email, entry.key);
        }
      },
    );

    test('rejects unknown accounts and incorrect passwords through the app data source', () async {
      final dataSource = MockAuthRemoteDataSource(authService: service);

      await expectLater(
        dataSource.login('unknown@example.com', 'anything123'),
        throwsA(isA<ApiException>()),
      );
      await expectLater(
        dataSource.login('demo@ticketmaster.mw', 'wrongpass'),
        throwsA(isA<ApiException>()),
      );
    });

    test('logs in with the seeded demo account', () async {
      final user = await service.logIn(
        email: 'demo@ticketmaster.mw',
        password: 'demo1234',
      );

      expect(
        user,
        const AppUser(
          id: 'U-001',
          name: 'Demo User',
          email: 'demo@ticketmaster.mw',
        ),
      );
    });

    test('rejects an incorrect password', () async {
      await expectLater(
        service.logIn(email: 'demo@ticketmaster.mw', password: 'wrongpass'),
        throwsA(
          isA<AuthException>().having(
            (exception) => exception.message,
            'message',
            'Incorrect email or password.',
          ),
        ),
      );
    });

    test(
      'rejects an unknown email with the same message as a wrong password',
      () async {
        String? wrongPasswordMessage;
        String? unknownEmailMessage;

        try {
          await service.logIn(
            email: 'demo@ticketmaster.mw',
            password: 'wrongpass',
          );
        } on AuthException catch (exception) {
          wrongPasswordMessage = exception.message;
        }

        try {
          await service.logIn(
            email: 'unknown@ticketmaster.mw',
            password: 'demo1234',
          );
        } on AuthException catch (exception) {
          unknownEmailMessage = exception.message;
        }

        expect(wrongPasswordMessage, 'Incorrect email or password.');
        expect(unknownEmailMessage, wrongPasswordMessage);
      },
    );

    test('creates an account and allows it to log in', () async {
      final createdUser = await service.signUp(
        name: 'New User',
        email: ' NEW@TicketMaster.mw ',
        password: 'newpass123',
      );
      final loggedInUser = await service.logIn(
        email: 'new@ticketmaster.mw',
        password: 'newpass123',
      );

      expect(createdUser.id, 'U-004');
      expect(createdUser.email, 'new@ticketmaster.mw');
      expect(loggedInUser, createdUser);
    });

    test('rejects a duplicate email without regard to case', () async {
      await expectLater(
        service.signUp(
          name: 'Duplicate User',
          email: 'DEMO@TicketMaster.mw',
          password: 'newpass123',
        ),
        throwsA(
          isA<AuthException>().having(
            (exception) => exception.message,
            'message',
            'An account with this email already exists.',
          ),
        ),
      );
    });

    test('validates email, name, and password on sign-up', () async {
      final invalidRequests = [
        service.signUp(
          name: 'New User',
          email: 'not-an-email',
          password: 'newpass123',
        ),
        service.signUp(
          name: ' ',
          email: 'new@ticketmaster.mw',
          password: 'newpass123',
        ),
        service.signUp(
          name: 'New User',
          email: 'new@ticketmaster.mw',
          password: 'short',
        ),
      ];

      for (final request in invalidRequests) {
        await expectLater(request, throwsA(isA<AuthException>()));
      }
    });
  });

  group('AuthController', () {
    test('tracks login and logout state', () async {
      final controller = AuthController(service);

      expect(controller.isLoggedIn, isFalse);

      await controller.logIn('demo@ticketmaster.mw', 'demo1234');
      expect(controller.isLoggedIn, isTrue);

      controller.logOut();
      expect(controller.isLoggedIn, isFalse);

      controller.dispose();
    });

    test('clears busy state and propagates errors when login fails', () async {
      final controller = AuthController(service);

      await expectLater(
        controller.logIn('unknown@ticketmaster.mw', 'wrongpass'),
        throwsA(isA<AuthException>()),
      );

      expect(controller.isBusy, isFalse);
      controller.dispose();
    });

    test('notifies listeners when authentication state changes', () async {
      final controller = AuthController(service);
      var notifications = 0;
      controller.addListener(() {
        notifications++;
      });

      await controller.logIn('demo@ticketmaster.mw', 'demo1234');
      controller.logOut();

      expect(notifications, greaterThanOrEqualTo(4));
      controller.dispose();
    });
  });
}
