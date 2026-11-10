# Backend API endpoints

Base URL: `http://localhost:8080`. OpenAPI JSON is available at `/v3/api-docs`; Swagger UI is at `/swagger-ui.html`.

Send authenticated requests with `Authorization: Bearer <token>`. JSON request and response dates use ISO-8601 local date-time strings, for example `2026-12-05T15:00:00` (no timezone suffix).

## Endpoint map

| Method and path | Access | Purpose |
|---|---|---|
| `GET /api/health` | Public | Health probe |
| `POST /api/auth/register` | Public | Register a CUSTOMER by default; privileged roles are disabled outside `dev` |
| `POST /api/auth/login` | Public | Email/password login |
| `POST /api/auth/google` | Public | Google ID-token login |
| `POST /api/auth/refresh` | Public | Refresh an access token |
| `GET /api/events?category=&search=` | Public | Published and cancelled events; case-insensitive category/search filters |
| `GET /api/events/{id}` | Public; draft only for its owner | Event details |
| `POST /api/events` | Authenticated | Create a draft event |
| `PUT /api/events/{id}` | Authenticated owner | Update an event |
| `PATCH /api/events/{id}/publish` | Authenticated owner | Publish an event (requires a ticket type; cancelled events cannot be published) |
| `PATCH /api/events/{id}/cancel` | Authenticated owner | Cancel an event |
| `GET /api/organizer/events` | ORGANIZER | List the organizer's events, including drafts |
| `POST /api/organizer/events/{eventId}/image` | ORGANIZER owner | Upload JPG/PNG cover, multipart field `file`, maximum 2 MB |
| `GET /api/events/{eventId}/ticket-types` | Public | List ticket types; optional `name` filter |
| `GET /api/ticket-types/{id}` | Public | Get one ticket type |
| `POST /api/events/{eventId}/ticket-types` | Authenticated | Add a ticket type |
| `PUT /api/ticket-types/{id}` | Authenticated owner | Update ticket type name (when unsold), stock and price |
| `DELETE /api/ticket-types/{id}` | ORGANIZER owner | Delete an unsold ticket type |
| `GET /api/interests` | Public | List available interests |
| `GET /api/customers/me` | Authenticated | Get or auto-create the current profile |
| `PUT /api/customers/me` | Authenticated | Update the current profile |
| `GET /api/customers/me/interests` | CUSTOMER | List selected interests |
| `POST /api/customers/me/interests?interestId={id}` | CUSTOMER | Add an interest |
| `DELETE /api/customers/me/interests/{interestId}` | CUSTOMER | Remove an interest |
| `POST /api/orders` | CUSTOMER | Reserve stock and place a PENDING order |
| `GET /api/orders/my` | CUSTOMER | List own orders |
| `GET /api/orders/{id}` | CUSTOMER owner | Read an order |
| `GET /api/orders/{id}/tickets` | CUSTOMER owner | List tickets for an order |
| `POST /api/orders/{id}/cancel` | CUSTOMER owner | Cancel a PENDING order and release stock |
| `POST /api/payments/checkout` | CUSTOMER order owner | Create a PayChangu checkout |
| `POST /api/payments/verify` | CUSTOMER order owner | Verify payment server-side and return order/tickets |
| `GET /api/payments/callback?tx_ref={txRef}` | Public gateway callback | Verify the transaction server-side, then redirect to the app |
| `GET /api/payments/return?tx_ref={txRef}&status={ignored}` | Public gateway return | Ignore gateway-supplied status, verify, then redirect |
| `POST /api/payments/webhook` | Public, signature-verified gateway notification | Verify the raw-body `Signature` HMAC and re-query PayChangu |
| `POST /api/dev/orders/{orderId}/mark-paid` | CUSTOMER order owner; only `dev` with demo enabled | Simulate a paid order |
| `GET /api/tickets/my` | Authenticated owner | List own tickets |
| `GET /api/tickets/{id}` | Authenticated owner | Read a ticket |
| `POST /api/tickets/{id}/cancel` | Authenticated owner | Cancel an unused ticket |
| `POST /api/tickets/validate` | VALIDATOR | Validate a ticket once |
| `GET /api/reports/events/{eventId}/sales` | Public | Event sales report |
| `GET /api/auth/qr/{text}` | Public | Render QR content as PNG |
| `GET /uploads/**` | Public | Serve uploaded event covers |

`POST /api/orders/{id}/status` is not available. Order payment state is changed only by the verified payment flow or the development-only demo endpoint.

## Example requests and responses

### Register and authenticate

Request:

```json
{
  "email": "customer@example.test",
  "password": "password123",
  "name": "Ada Example"
}
```

Successful response (`AuthResponse`):

```json
{
  "token": "<access-token>",
  "refreshToken": "<refresh-token>",
  "user": {
    "id": 12,
    "name": "Ada Example",
    "email": "customer@example.test",
    "role": "CUSTOMER"
  }
}
```

`role` is optional and defaults to `CUSTOMER`. Outside the dev profile, requesting another role returns 403.

### Event list and details

`GET /api/events?category=Concerts&search=Afro` and `GET /api/events/{id}` return the same `EventResponse` shape. Ticket aggregates are calculated only from that event's own ticket types:

```json
{
  "id": 7,
  "title": "AfroFusion Live 2026",
  "category": "Concerts",
  "genre": null,
  "venue": "Comesa Hall",
  "location": "Blantyre",
  "startTime": "2026-11-21T18:00:00",
  "endTime": "2026-11-21T23:30:00",
  "status": "PUBLISHED",
  "availability": "AVAILABLE",
  "coverImagePath": "/uploads/events/8f3a1c2e.jpg",
  "minPrice": 15000,
  "capacity": 300,
  "remainingTickets": 300,
  "ticketTypes": [
    {"id": 11, "name": "Standard", "price": 15000, "totalQuantity": 250, "remaining": 250},
    {"id": 12, "name": "VIP", "price": 30000, "totalQuantity": 50, "remaining": 50}
  ]
}
```

Availability is `CANCELLED` for cancelled events, `ENDED` when the start or end has passed, `SOLD_OUT` only when ticket types exist and none remain, or `AVAILABLE`. Events accept `title`, `category` (defaults to `Other`), nullable `genre` (maximum 80 characters), `venue`, `location`, and `startTime` or legacy `dateTime`; either start field fills the other. End time must be later than start time. Dates serialize as ISO local date-times without timezone or milliseconds.

### Place an order

Request:

```json
{
  "eventId": 42,
  "items": [
    {
      "ticketTypeId": 101,
      "quantity": 2
    }
  ]
}
```

Successful `OrderResponse`:

```json
{
  "id": 501,
  "eventId": 42,
  "totalAmount": 30000.00,
  "status": "PENDING",
  "createdAt": "2026-11-09T13:00:00",
  "items": [
    {
      "ticketTypeId": 101,
      "quantity": 2,
      "unitPrice": 15000.00
    }
  ]
}
```

Only PUBLISHED, not-ended events are orderable. The event must match every requested ticket type; duplicate ticket types are rejected. The default maximum is 10 tickets per order. Stock is reserved when the PENDING order is created.

### Checkout

`POST /api/payments/checkout` request (any `amount` supplied by a client is ignored):

```json
{
  "orderId": 501
}
```

Successful response:

```json
{
  "orderId": 501,
  "txRef": "a9b91d06-846f-4b2b-a5aa-b64cb34c5f8c",
  "checkoutUrl": "https://checkout.paychangu.example/session",
  "amount": 30000.00,
  "currency": "MWK",
  "status": "PENDING"
}
```

### Verify payment

`POST /api/payments/verify` request:

```json
{
  "orderId": 501
}
```

Full `PaidOrderResponse` example:

```json
{
  "order": {
    "id": 501,
    "eventId": 42,
    "totalAmount": 30000.00,
    "status": "PAID",
    "createdAt": "2026-11-09T13:00:00",
    "items": [
      {
        "ticketTypeId": 101,
        "quantity": 2,
        "unitPrice": 15000.00
      }
    ]
  },
  "tickets": [
    {
      "id": 9001,
      "orderId": 501,
      "ticketCode": "7ef7a1ad-c409-48f8-8144-a5dfcfedcc09",
      "eventId": 42,
      "eventTitle": "AfroFusion Live 2026",
      "venue": "Comesa Hall",
      "location": "Blantyre",
      "eventDateTime": "2026-12-05T15:00:00",
      "eventStartTime": "2026-12-05T15:00:00",
      "eventEndTime": "2026-12-05T21:00:00",
      "ticketTypeId": 101,
      "ticketTypeName": "Standard",
      "ticketPrice": 15000.00,
      "status": "VALID",
      "issuedAt": "2026-11-09T13:05:00",
      "usedAt": null,
      "qrContent": "7ef7a1ad-c409-48f8-8144-a5dfcfedcc09",
      "buyerName": "Ada Example",
      "buyerEmail": "customer@example.test",
      "paymentReference": "a9b91d06-846f-4b2b-a5aa-b64cb34c5f8c",
      "currency": "MWK",
      "purchasedAt": "2026-11-09T13:05:00",
      "coverImagePath": "/uploads/events/afrofusion-live-2026.jpg"
    }
  ],
  "paymentStatus": "PAID"
}
```

The server accepts a payment only when the verified transaction reference matches the stored reference, the provider status is `success`, currency is `MWK`, and verified amount is at least the database order total. A failed provider status leaves the order PENDING.

### Standard error response

Errors use this JSON shape (validation responses use the first field error as `message`):

```json
{
  "timestamp": "2026-11-09T13:05:00",
  "status": 404,
  "error": "Not Found",
  "message": "Order not found.",
  "path": "/api/orders/9999"
}
```

The gateway failure response is 502 with message `Payment service unavailable.` Unexpected server errors return 500 with message `Unexpected server error.` and no stack trace.

### Redirect URI and dev accounts

The default app redirect target is `myapp://payment-result`; redirects append the verified `status` and `tx_ref` query parameters. Override it with `APP_PAYMENT_REDIRECT_URI` / `app.payment.app-redirect-uri`.

When running with the `dev` profile and `app.seed.enabled=true`, the seeded accounts are:

| Email | Role | Dev-only password |
|---|---|---|
| `customer@test.com` | CUSTOMER | `Password123` |
| `organizer@test.com` | ORGANIZER | `Password123` |
| `validator@test.com` | VALIDATOR | `Password123` |

Do not use these development accounts in a deployed environment.
