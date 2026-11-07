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

## Password recovery

When `API_BASE_URL` is empty, the app uses an in-memory demo service. It accepts
the seeded demo accounts, displays the generated 6-digit code in the app instead
of sending email, and expires codes after 10 minutes. A successful reset updates
the mock account password for the current app session.

With a backend configured, the app expects:

- `POST /auth/forgot-password` with `{"email":"..."}`. The backend should send a
  short-lived verification code by email and return a success message. Do not
  return the verification code in the response.
- `POST /auth/reset-password` with
  `{"email":"...","code":"...","newPassword":"..."}`. The backend must enforce
  code validity, expiry, and one-time use, then securely hash and save the new
  password. Return a JSON response with a 2xx status to complete the reset.

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
