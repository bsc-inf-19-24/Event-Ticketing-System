import 'package:flutter/foundation.dart';

import '../../../features/auth/logic/auth_controller.dart';
import '../../../models/ticket.dart';
import '../../../services/ticket_storage.dart';

/// Keeps the authenticated user's purchased tickets available to the app.
class TicketsController extends ChangeNotifier {
  TicketsController({TicketStorage? storage, AuthController? auth})
    : _storage = storage ?? TicketStorage(),
      _auth = auth ?? authController {
    _auth.addListener(_onAuthChanged);
    _onAuthChanged();
  }

  final TicketStorage _storage;
  final AuthController _auth;
  List<Ticket> _tickets = const [];
  String? _userId;
  bool _loading = false;
  int _loadGeneration = 0;
  bool _disposed = false;

  List<Ticket> get tickets => List.unmodifiable(_tickets);
  bool get isLoading => _loading;
  int get count => _tickets.length;

  void _onAuthChanged() {
    final userId = _auth.user?.id;
    if (userId == _userId) return;
    _userId = userId;
    _loadGeneration++;
    _tickets = const [];
    if (userId == null) {
      _loading = false;
      if (!_disposed) notifyListeners();
    } else {
      if (!_disposed) notifyListeners();
      load();
    }
  }

  /// Loads only tickets belonging to the current authenticated user.
  Future<void> load() async {
    final userId = _auth.user?.id;
    _userId = userId;
    final generation = ++_loadGeneration;
    if (userId == null) {
      _tickets = const [];
      _loading = false;
      if (!_disposed) notifyListeners();
      return;
    }
    _loading = true;
    if (!_disposed) notifyListeners();
    try {
      final saved = await _storage.getSavedTickets(userId: userId);
      if (!_disposed &&
          generation == _loadGeneration &&
          _auth.user?.id == userId) {
        _tickets = saved.reversed.toList();
      }
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

  /// Clears the in-memory ticket list.
  void clear() {
    _loadGeneration++;
    _tickets = const [];
    _userId = null;
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _auth.removeListener(_onAuthChanged);
    super.dispose();
  }
}

/// Shared ticket state for navigation, home, and purchase screens.
final ticketsController = TicketsController();
