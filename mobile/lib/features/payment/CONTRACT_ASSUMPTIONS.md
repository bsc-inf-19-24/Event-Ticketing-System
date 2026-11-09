# Backend contract assumptions

The backend contract has not been supplied for the payment-specific routes. The
app centralizes the known routes in `lib/core/api_endpoints.dart`; the two
payment routes there are guesses and must be checked with the backend team.

The implementation currently assumes:

- `POST /api/orders` accepts `eventId`, `ticketTypeId`, and `quantity`. It does
  not send a price or total; the server calculates and returns the price.
- `Idempotency-Key` is accepted on order creation to prevent duplicate orders
  after a timeout/retry.
- `POST /api/orders/{id}/payment` accepts `method` and optional `phoneNumber`,
  then returns a checkout URL in `checkoutUrl`, `checkout_url`, `paymentUrl`, or
  `payment_url`. The URL must use HTTPS.
- `GET /api/orders/{id}` returns an order with a `status` and any issued
  `tickets`. `GET /api/orders/my` returns an array of orders, optionally under
  `data` or `orders`.
- The optional demo confirmation route returns tickets when it confirms an
  order. Demo confirmation and local-ticket fallback are disabled by default.
- Ticket responses contain the common fields accepted by
  `Ticket.fromServer`; field variants are parsed defensively.

No client-side payment result is treated as proof of payment. Production tickets
are shown only when the authenticated server reports a paid/confirmed order.

The app's current event catalog is static sample data and has no event API
adapter or server IDs. Real checkout rejects these entries instead of creating
orders with guessed IDs. Connecting the real catalog requires the backend event
list/detail route and response schema; set `USE_FAKE_EVENTS=false` to hide the
sample catalog until that integration is available.
