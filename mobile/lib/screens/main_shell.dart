import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../features/auth/logic/auth_controller.dart';
import '../features/payment/logic/payment_return_handler.dart';
import '../features/payment/services/api_payment_service.dart';
import '../features/payment/logic/payment_controller.dart';
import '../features/orders/services/order_repository.dart';
import '../features/orders/models/order.dart';
import '../features/tickets/logic/tickets_controller.dart';
import '../models/event.dart';
import 'payment_result_screen.dart' as pending_result;
import '../theme/app_colors.dart';
import 'home_screen.dart';

import 'package:mobile/features/profile/ui/profile_screen.dart';

import 'tickets_screen.dart';

/// Selected bottom-navigation tab, including requests from pushed screens.
final ValueNotifier<int> mainTabIndex = ValueNotifier<int>(0);

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSubscription;
  late final PaymentReturnHandler _returnHandler;
  String? _savedOrderId;
  String? _returnError;

  @override
  void initState() {
    super.initState();
    _returnHandler = PaymentReturnHandler(onReturn: _verifyReturnedOrder);
    unawaited(_restorePaymentReturn());
  }

  Future<void> _restorePaymentReturn() async {
    final prefs = await SharedPreferences.getInstance();
    final savedOrderId = prefs.getString(
      PaymentController.pendingOrderPreference,
    );
    if (!mounted) return;
    if (savedOrderId != null) {
      _savedOrderId = savedOrderId;
      _returnHandler.preserveOrder(savedOrderId);
      setState(() {});
    }
    _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
      unawaited(_returnHandler.handle(uri));
    });
    final initialUri = await _appLinks.getInitialLink();
    if (initialUri != null) await _returnHandler.handle(initialUri);
  }

  Future<void> _verifyReturnedOrder(
    String orderId, {
    String? status,
    String? txRef,
  }) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(
        PaymentController.pendingOrderPreference,
        orderId,
      );
      if (mounted) setState(() => _savedOrderId = orderId);
      final api = ApiPaymentService();
      final raw = await api.getOrder(orderId);
      final orderData = raw;
      final event = Event(
        id: _string(orderData['eventId'] ?? _nested(orderData['event'])['id']),
        title: _string(
          orderData['eventName'] ?? _nested(orderData['event'])['name'],
          fallback: 'Your event',
        ),
        date: _string(
          orderData['eventDate'] ?? _nested(orderData['event'])['date'],
        ),
        time: '',
        venue: _string(
          orderData['venue'] ?? _nested(orderData['event'])['venue'],
        ),
        price: _int(orderData['totalAmount'] ?? orderData['total']),
        imagePath: '',
        category: '',
      );
      final controller = PaymentController(
        paymentService: api,
        orderRepository: OrderRepository(),
        ticketsController: ticketsController,
      );
      // Return-link status and tx_ref are context only; the backend verify call
      // below is the sole source used to decide whether the order is paid.
      controller.order = Order(
        id: orderId,
        userId: _string(
          orderData['customerId'] ??
              orderData['customer_id'] ??
              orderData['userId'] ??
              orderData['user_id'],
          fallback: authController.stableUserId ?? '',
        ),
        eventTitle: event.title,
        eventVenue: event.venue,
        eventDate: event.date,
        items: const [],
        total: event.price,
        status: _string(orderData['status'], fallback: 'PENDING'),
        txRef: txRef ?? '',
        paymentMethod: 'PayChangu',
        createdAt: DateTime.now(),
      );
      final result = await controller.verifyPendingOrder(event);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => pending_result.PaymentResultScreen(
            event: event,
            controller: controller,
            initialPaid: result,
            initialMessage: controller.failureReason,
          ),
        ),
      );
      final prefs = await SharedPreferences.getInstance();
      final stillPending = prefs.getString(
        PaymentController.pendingOrderPreference,
      );
      if (mounted) {
        setState(() {
          _savedOrderId = stillPending;
          _returnError = null;
        });
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _returnError = error.toString());
    }
  }

  Map<String, dynamic> _nested(dynamic value) =>
      value is Map ? Map<String, dynamic>.from(value) : const {};

  String _string(dynamic value, {String fallback = ''}) => value is String
      ? value
      : value is num
      ? value.toString()
      : fallback;
  int _int(dynamic value) =>
      value is num ? value.toInt() : int.tryParse('$value') ?? 0;

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: authController,
      builder: (context, child) => ValueListenableBuilder<int>(
        valueListenable: mainTabIndex,
        builder: (context, currentIndex, _) => Scaffold(
          backgroundColor: AppColors.background,
          body: Column(
            children: [
              if (_savedOrderId != null)
                MaterialBanner(
                  content: Text(
                    _returnError ?? 'Checkout was interrupted or the return link was missed. Verify the saved order to retry.',
                  ),
                  leading: const Icon(Icons.pending_actions),
                  actions: [
                    TextButton(
                      onPressed: () => _verifyReturnedOrder(_savedOrderId!),
                      child: const Text('Verify order'),
                    ),
                  ],
                ),
              Expanded(
                child: IndexedStack(
                  index: currentIndex,
                  children: [
                    HomeScreen(onViewTickets: () => mainTabIndex.value = 1),
                    const TicketsScreen(),
                    const ProfileScreen(),
                  ],
                ),
              ),
            ],
          ),
          bottomNavigationBar: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(30),
                child: NavigationBar(
                  height: 64,
                  backgroundColor: AppColors.background,
                  indicatorColor: Colors.transparent,
                  labelBehavior:
                      NavigationDestinationLabelBehavior.onlyShowSelected,
                  labelTextStyle: WidgetStateProperty.all(
                    const TextStyle(
                      color: AppColors.accent,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  selectedIndex: currentIndex,
                  onDestinationSelected: (index) => mainTabIndex.value = index,
                  destinations: const [
                    NavigationDestination(
                      label: 'Home',
                      icon: Icon(Icons.home_outlined, color: Colors.white70),
                      selectedIcon: Icon(Icons.home, color: AppColors.accent),
                    ),
                    NavigationDestination(
                      label: 'Tickets',
                      icon: Icon(
                        Icons.account_balance_wallet_outlined,
                        color: Colors.white70,
                      ),
                      selectedIcon: Icon(
                        Icons.account_balance_wallet,
                        color: AppColors.accent,
                      ),
                    ),
                    NavigationDestination(
                      label: 'Profile',
                      icon: Icon(Icons.person_outline, color: Colors.white70),
                      selectedIcon: Icon(Icons.person, color: AppColors.accent),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
