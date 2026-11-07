# mobile

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Offline ticket storage

Downloaded tickets are stored in the application's SQLite database, including
their event details, price, status, QR data, and download date. Ticket IDs are
unique, and downloaded tickets remain available after the app is closed and
reopened. Tickets saved by earlier versions in local preferences are imported
into SQLite the first time the database is opened.
## Server connection and authentication

The app connects to `http://10.0.2.2:8080` by default (the Android emulator's
host-machine address). Override it with `--dart-define=API_BASE_URL=https://...`
or change it in **Profile > Settings > Server connection**. Enter the server
origin without an `/api` suffix. Requests time out after 15 seconds and report a
retryable connection message when the server cannot be reached.

The app uses these backend routes:

- `POST /api/auth/register` with name, email, password, and role
  (`CUSTOMER`, `ORGANIZER`, or `VALIDATOR`).
- `POST /api/auth/login` with email and password. Login and registration return
  `token` (or `accessToken`) and `refreshToken`.
- `POST /api/auth/google` with `{"idToken":"..."}` and
  `GET /api/auth/qr/{text}` returning a PNG image.
- `POST /api/auth/refresh` with `{"refreshToken":"..."}`.
- `GET /api/customers/me` to restore the current session.
- `PUT /api/customers/me` to update the current profile.
- `POST /api/auth/forgot-password` with `{"email":"..."}`. The backend should
  send a short-lived verification code by email and must not return the code.
- `POST /api/auth/reset-password` with
  `{"email":"...","code":"...","newPassword":"..."}`. The backend must enforce
  code validity, expiry, and one-time use, then securely hash and save the new
  password.

Access and refresh tokens are stored in platform secure storage. Expired access
tokens are refreshed once and the original request is retried. Logging out clears
both tokens. Set `--dart-define=USE_FAKE_AUTH=true` only to use the in-memory
demo accounts and password-reset flow instead of the server.

The app validates password complexity and confirmation before submitting. Code
validation and password persistence remain server responsibilities in production.

## Google sign-in

Login and signup use `google_sign_in` to obtain a Google ID token, then exchange
it with the configured backend using `POST /auth/google` and
`{"idToken":"..."}`. The backend must validate the token with Google, create or
find the account, and return the same JSON shape as `POST /auth/login`, including
a non-empty `token` (or `accessToken`). The Google ID token must not be used as
the application session token.

Configure platform OAuth clients in Google Cloud Console. If client IDs are not
provided by platform configuration, pass them at build time:

```sh
flutter run \
  --dart-define=API_BASE_URL=https://your-api.example.com \
  --dart-define=GOOGLE_CLIENT_ID=your-client-id.apps.googleusercontent.com \
  --dart-define=GOOGLE_SERVER_CLIENT_ID=your-web-client-id.apps.googleusercontent.com
```

Register the Android package name and signing certificate fingerprints, and add
the iOS URL scheme/client configuration for supported platforms. Google sign-in
requires a configured backend because the mock service cannot verify Google
identity tokens.

## PayChangu payments

The Flutter client defaults to the existing offline simulator. To use the hosted
PayChangu flow, run with `--dart-define=USE_FAKE_PAYMENTS=false` and configure
`API_BASE_URL` to your authenticated application backend. The app never calls
PayChangu directly and must never contain the PayChangu secret key.

The backend needs to provide these authenticated endpoints:

- `POST /payments/paychangu/checkout`: accept `amount`, `currency`, `email`,
  `first_name`, `last_name`, `tx_ref`, optional `mobile`, and `meta`; initiate
  PayChangu's `POST https://api.paychangu.com/payment` using a server-held key;
  set `callback_url` and `return_url` from server configuration; return PayChangu's
  hosted checkout response shape (`data.checkout_url` and nested transaction data).
- `GET /payments/paychangu/verify/{tx_ref}`: call PayChangu's transaction
  `GET https://api.paychangu.com/verify-payment/{tx_ref}` endpoint on the server and return a response with
  `data.tx_ref`, `data.status`, `data.currency`, and `data.amount`. Do not rely on
  the app's return URL or a client confirmation to mark an order paid.
- A PayChangu webhook endpoint: verify the webhook signature server-side, then
  update the order idempotently. Issue tickets only after checking the verified
  transaction reference, currency, amount, and success status.

The app opens hosted checkout in the browser. After returning to the app, the
customer taps **I completed payment — verify**. The app asks the backend to
verify the transaction and creates tickets only when it confirms a matching
successful MWK payment. Set the PayChangu dashboard and backend URLs to reachable
HTTPS endpoints before testing real payments.
The app validates signup fields before submitting. Authentication, profile
validation, password reset, and token issuance remain server responsibilities.
