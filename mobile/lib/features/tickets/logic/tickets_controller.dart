import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/network/api_client.dart';
import '../../../features/auth/logic/auth_controller.dart';
import '../../../models/ticket.dart';
import '../../../services/ticket_repository.dart';
import '../../../services/ticket_storage.dart';
import 'connectivity_monitor.dart';

/// Keeps the authenticated user's purchased tickets available to the app.
class TicketsController extends ChangeNotifier {
  TicketsController({
    TicketStorage? storage,
    AuthController? auth,
    TicketRepository? repository,
    ConnectivityMonitor? connectivity,
  }) : _storage = storage ?? TicketStorage(),
       _auth = auth ?? authController,
       _repository =
           repository ?? TicketRepository(storage: storage ?? TicketStorage()),
       _connectivity = connectivity ?? connectivityMonitor {
    _auth.addListener(_onAuthChanged);
    _connectivity.addListener(_onConnectivityChanged);
    _onAuthChanged();
  }

  final TicketStorage _storage;
  final AuthController _auth;
  final TicketRepository _repository;
  final ConnectivityMonitor _connectivity;
  List<Ticket> _tickets = const [];
  String? _userId;
  String? _errorMessage;
  bool _loading = false;
  bool _isOffline = false;
  DateTime? _lastSynced;
  int _loadGeneration = 0;
  bool _disposed = false;

  List<Ticket> get tickets => List.unmodifiable(_tickets);
  bool get isLoading => _loading;
  int get count => _tickets.length;
  String? get errorMessage => _errorMessage;
  bool get isOffline => _isOffline;
  DateTime? get lastSynced => _lastSynced;

  void _onAuthChanged() {
    final userId = _auth.user?.id;
    if (userId == _userId) return;
    _userId = userId;
    _loadGeneration++;
    _tickets = const [];
    _errorMessage = null;
    _isOffline = false;
    _lastSynced = null;
    if (userId == null) {
      _loading = false;
      if (!_disposed) notifyListeners();
    } else {
      if (!_disposed) notifyListeners();
      load();
    }
  }

  void _onConnectivityChanged() {
    if (_auth.user != null) unawaited(load());
  }

  /// Loads only tickets belonging to the current authenticated user.
  Future<void> load() async {
    final userId = _auth.user?.id;
    _userId = userId;
    final generation = ++_loadGeneration;
    if (userId == null) {
      _tickets = const [];
      _loading = false;
      _isOffline = false;
      _errorMessage = null;
      if (!_disposed) notifyListeners();
      return;
    }
    _loading = true;
    _errorMessage = null;
    if (!_disposed) notifyListeners();
    try {
      final result = await _repository.load(
        userId: userId,
        hasConnection: _connectivity.isOnline,
      );
      if (!_disposed &&
          generation == _loadGeneration &&
          _auth.user?.id == userId) {
        _tickets = result.tickets;
        _isOffline = result.isOffline;
        _lastSynced = result.lastSynced;
      }
    } on ApiException catch (error) {
      if (error.statusCode == 401) _auth.logOut();
      if (!_disposed && generation == _loadGeneration) {
        _errorMessage = error.message;
      }
      rethrow;
    } catch (error) {
      if (!_disposed && generation == _loadGeneration) {
        _errorMessage = error.toString();
      }
      rethrow;
    } finally {
      if (!_disposed && generation == _loadGeneration) {
        _loading = false;
        notifyListeners();
      }
    }
  }

  /// Persists tickets and updates the current user's list.
  Future<void> addTickets(List<Ticket> tickets) async {
    final userId = _auth.user?.id;
    if (userId == null) throw StateError('A logged-in customer is required.');
    if (tickets.any((ticket) => ticket.userId != userId)) {
      throw StateError('Tickets can only be saved for their owning customer.');
    }
    await _storage.saveTickets(tickets);
    await load();
  }

  Future<Ticket> loadTicketDetails(String ticketId) {
    final userId = _auth.user?.id;
    if (userId == null) {
      throw StateError('A logged-in customer is required.');
    }
    return _repository
        .getTicketDetails(
          ticketId: ticketId,
          userId: userId,
          hasConnection: _connectivity.isOnline,
        )
        .catchError((Object error) {
          if (error is ApiException && error.statusCode == 401) {
            _auth.logOut();
          }
          throw error;
        });
  }

  /// Clears the in-memory ticket list.
  void clear() {
    _loadGeneration++;
    _tickets = const [];
    _userId = null;
    _errorMessage = null;
    _isOffline = false;
    _lastSynced = null;
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _auth.removeListener(_onAuthChanged);
    _connectivity.removeListener(_onConnectivityChanged);
    super.dispose();
  }
}

/// Shared ticket state for navigation, home, and purchase screens.
final ticketsController = TicketsController();
